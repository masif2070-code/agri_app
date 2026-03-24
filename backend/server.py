from __future__ import annotations

import math
import os
from datetime import date, timedelta
from typing import Any

import requests
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

try:
    import ee
except Exception:  # pragma: no cover
    ee = None


app = FastAPI(title="Agri GIS Backend", version="0.1.0")

# Allow local Flutter clients (web/desktop) during development.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:54321",
        "http://127.0.0.1:54321",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class AnalyzeRequest(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    selected_crop: str | None = None
    polygon: list[list[float]] | None = None


class AnalyzeResponse(BaseModel):
    detected_crop: str
    confidence: float
    ndvi: float | None
    precipitation_7day_mm: float
    reference_et0_7day_mm: float
    estimated_crop_water_need_7day_mm: float
    net_water_balance_7day_mm: float
    field_condition: str
    recommendation: str
    earth_engine_ready: bool
    diagnostic: str | None = None


class EETilesResponse(BaseModel):
    layer: str
    url_template: str


# Cache tile URL templates for nearby points to reduce repeated EE map-id calls.
_EE_TILE_CACHE: dict[str, tuple[date, str]] = {}
_EE_TILE_CACHE_TTL_DAYS = 1


def _tile_cache_key(latitude: float, longitude: float, layer: str) -> str:
    # 4 decimals ~= 11m precision, enough for interactive map picking.
    return f"{round(latitude, 4)}:{round(longitude, 4)}:{layer}"


def _fetch_precipitation_7day(latitude: float, longitude: float) -> float:
    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={latitude}&longitude={longitude}&daily=precipitation_sum"
    )
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()
        daily = data.get("daily", {})
        precipitation = daily.get("precipitation_sum", [])
        return float(sum(precipitation[:7]))
    except Exception:
        return 0.0


def _estimate_daily_et0_hargreaves(
    latitude: float,
    day_value: date,
    temperature_max: float,
    temperature_min: float,
) -> float:
    day_of_year = day_value.timetuple().tm_yday
    latitude_radians = math.radians(latitude)
    inverse_relative_distance = 1 + 0.033 * math.cos((2 * math.pi / 365) * day_of_year)
    solar_declination = 0.409 * math.sin((2 * math.pi / 365) * day_of_year - 1.39)
    sunset_hour_angle = math.acos(
        max(-1.0, min(1.0, -math.tan(latitude_radians) * math.tan(solar_declination)))
    )
    extraterrestrial_radiation = (
        (24 * 60 / math.pi)
        * 0.0820
        * inverse_relative_distance
        * (
            sunset_hour_angle * math.sin(latitude_radians) * math.sin(solar_declination)
            + math.cos(latitude_radians)
            * math.cos(solar_declination)
            * math.sin(sunset_hour_angle)
        )
    )
    temperature_mean = (temperature_max + temperature_min) / 2
    temperature_range = max(temperature_max - temperature_min, 0.0)
    return max(
        0.0,
        0.0023 * extraterrestrial_radiation * (temperature_mean + 17.8) * math.sqrt(temperature_range),
    )


def _fetch_weather_summary(latitude: float, longitude: float) -> tuple[float, float]:
    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={latitude}&longitude={longitude}"
        "&daily=precipitation_sum,et0_fao_evapotranspiration,temperature_2m_max,temperature_2m_min"
        "&timezone=Asia%2FKarachi"
    )
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()
        daily = data.get("daily", {})
        precipitation = daily.get("precipitation_sum", [])
        et0_values = daily.get("et0_fao_evapotranspiration", [])
        daily_dates = daily.get("time", [])
        temperature_max_values = daily.get("temperature_2m_max", [])
        temperature_min_values = daily.get("temperature_2m_min", [])

        resolved_et0_values: list[float] = []
        forecast_days = min(
            7,
            len(daily_dates),
            len(temperature_max_values),
            len(temperature_min_values),
        )
        for index in range(forecast_days):
            raw_et0 = et0_values[index] if index < len(et0_values) else 0.0
            et0_value = float(raw_et0 or 0.0)
            if et0_value > 0:
                resolved_et0_values.append(et0_value)
                continue

            resolved_et0_values.append(
                _estimate_daily_et0_hargreaves(
                    latitude,
                    date.fromisoformat(daily_dates[index]),
                    float(temperature_max_values[index]),
                    float(temperature_min_values[index]),
                )
            )

        precipitation_7day = float(sum(precipitation[:7]))
        et0_7day = float(sum(resolved_et0_values[:7]))
        return precipitation_7day, et0_7day
    except Exception:
        return _fetch_precipitation_7day(latitude, longitude), 0.0


def _ee_initialize_if_possible() -> bool:
    ok, _ = _ee_initialize_with_env()
    return ok


def _ee_project_id_from_env() -> str | None:
    # Support common cloud env var names to avoid deployment-specific mismatches.
    return (
        os.getenv("EE_PROJECT_ID")
        or os.getenv("GOOGLE_CLOUD_PROJECT")
        or os.getenv("GCLOUD_PROJECT")
    )


def _ee_initialize_with_env() -> tuple[bool, str | None]:
    if ee is None:
        return False, "Earth Engine Python package is unavailable in the backend."

    project_id = _ee_project_id_from_env()
    service_account = os.getenv("EE_SERVICE_ACCOUNT")
    private_key = os.getenv("EE_PRIVATE_KEY")

    try:
        if service_account and private_key:
            key_data = private_key.replace("\\n", "\n")
            credentials = ee.ServiceAccountCredentials(service_account, key_data=key_data)
            if project_id:
                ee.Initialize(credentials=credentials, project=project_id)
            else:
                ee.Initialize(credentials=credentials)
            return True, None

        if project_id:
            ee.Initialize(project=project_id)
        else:
            ee.Initialize()
        return True, None
    except Exception as exc:
        return False, f"Earth Engine initialization failed: {exc}"


def _earth_engine_diagnostic() -> tuple[bool, str | None]:
    if ee is None:
        return False, "Earth Engine Python package is unavailable in the backend."

    project_id = _ee_project_id_from_env()
    if not project_id:
        return (
            False,
            "Earth Engine is authenticated, but project id is missing. Set EE_PROJECT_ID (or GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT).",
        )

    return _ee_initialize_with_env()


def _build_ee_tile_url(latitude: float, longitude: float, layer: str) -> str:
    cache_key = _tile_cache_key(latitude, longitude, layer)
    cached = _EE_TILE_CACHE.get(cache_key)
    if cached is not None:
        cached_on, cached_url = cached
        if (date.today() - cached_on).days <= _EE_TILE_CACHE_TTL_DAYS:
            return cached_url

    if not _ee_initialize_if_possible():
        raise HTTPException(
            status_code=503,
            detail="Earth Engine is not initialized. Set credentials and EE_PROJECT_ID.",
        )

    assert ee is not None
    region = ee.Geometry.Point([longitude, latitude]).buffer(12000)

    image = (
        ee.ImageCollection("COPERNICUS/S2_SR_HARMONIZED")
        .filterBounds(region)
        .filterDate(str(date.today() - timedelta(days=120)), str(date.today()))
        .sort("CLOUDY_PIXEL_PERCENTAGE")
        .first()
    )

    if image is None:
        raise HTTPException(status_code=404, detail="No Earth Engine image found for area.")

    if layer == "ndvi":
        rendered = image.normalizedDifference(["B8", "B4"]).rename("NDVI")
        vis = {
            "min": 0,
            "max": 0.9,
            "palette": ["#8b0000", "#f4d03f", "#7fbf3f", "#006400"],
        }
    else:
        rendered = image.select(["B4", "B3", "B2"])
        vis = {"min": 0, "max": 3000, "gamma": 1.2}

    map_id = rendered.getMapId(vis)
    tile_fetcher = map_id.get("tile_fetcher")
    if tile_fetcher is None or not hasattr(tile_fetcher, "url_format"):
        raise HTTPException(status_code=500, detail="Unable to build Earth Engine tile URL.")

    _EE_TILE_CACHE[cache_key] = (date.today(), tile_fetcher.url_format)
    return tile_fetcher.url_format


def _centroid_from_polygon(polygon: list[list[float]]) -> tuple[float, float] | None:
    if len(polygon) < 3:
        return None
    try:
        lat = sum(point[0] for point in polygon) / len(polygon)
        lon = sum(point[1] for point in polygon) / len(polygon)
        return lat, lon
    except Exception:
        return None


def _validate_polygon(polygon: list[list[float]] | None) -> list[list[float]] | None:
    if polygon is None:
        return None
    if len(polygon) < 3:
        return None
    valid_points: list[list[float]] = []
    for point in polygon:
        if not isinstance(point, list) or len(point) != 2:
            continue
        lat, lon = point
        if not (-90 <= lat <= 90 and -180 <= lon <= 180):
            continue
        valid_points.append([float(lat), float(lon)])
    if len(valid_points) < 3:
        return None
    return valid_points


def _compute_ndvi_mean(
    latitude: float,
    longitude: float,
    polygon: list[list[float]] | None,
) -> float | None:
    if not _ee_initialize_if_possible():
        return None

    assert ee is not None
    point = ee.Geometry.Point([longitude, latitude])

    if polygon and len(polygon) >= 3:
        ring = [[p[1], p[0]] for p in polygon]
        if ring[0] != ring[-1]:
            ring.append(ring[0])
        region = ee.Geometry.Polygon([ring])
    else:
        # 10 km buffer gives a small field neighborhood instead of one pixel.
        region = point.buffer(5000)

    image = (
        ee.ImageCollection("COPERNICUS/S2_SR_HARMONIZED")
        .filterBounds(region)
        .filterDate(str(date.today().replace(month=1, day=1)), str(date.today()))
        .sort("CLOUDY_PIXEL_PERCENTAGE")
        .first()
    )

    if image is None:
        return None

    ndvi = image.normalizedDifference(["B8", "B4"]).rename("NDVI")
    value = ndvi.reduceRegion(
        reducer=ee.Reducer.mean(),
        geometry=region,
        scale=20,
        maxPixels=1_000_000,
    ).get("NDVI")

    if value is None:
        return None

    try:
        return float(value.getInfo())
    except Exception:
        return None


def _detect_crop_from_ndvi(ndvi: float | None) -> tuple[str, float]:
    # Starter heuristic model. Replace with trained classifier later.
    if ndvi is None:
        return "Unknown", 0.35
    if ndvi >= 0.72:
        return "Rice", 0.68
    if ndvi >= 0.60:
        return "Maize", 0.64
    if ndvi >= 0.46:
        return "Wheat", 0.61
    if ndvi >= 0.30:
        return "Potato", 0.56
    return "Bare/Low Vegetation", 0.50


def _crop_coefficient(crop: str) -> float:
    coefficients = {
        "Rice": 1.10,
        "Maize": 1.00,
        "Wheat": 0.90,
        "Potato": 0.85,
        "Bare/Low Vegetation": 0.60,
        "Unknown": 0.95,
    }
    return coefficients.get(crop, 0.95)


def _estimated_crop_water_need_7day(crop: str, reference_et0_7day: float) -> float:
    return reference_et0_7day * _crop_coefficient(crop)


def _condition_from_signals(
    ndvi: float | None,
    precipitation_7day: float,
    net_water_balance_7day: float,
) -> str:
    if ndvi is not None and ndvi < 0.32 and net_water_balance_7day < -12:
        return "Water stress risk"
    if net_water_balance_7day > 20 or precipitation_7day > 45:
        return "Waterlogging risk"
    if ndvi is not None and ndvi > 0.58 and net_water_balance_7day >= -8:
        return "Healthy canopy"
    return "Moderate condition"


def _recommendation(
    condition: str,
    crop: str,
    precipitation_7day: float,
    reference_et0_7day: float,
    estimated_crop_water_need_7day: float,
    net_water_balance_7day: float,
) -> str:
    if condition == "Water stress risk":
        return (
            f"{crop}: Expected rainfall is {precipitation_7day:.1f} mm against about "
            f"{estimated_crop_water_need_7day:.1f} mm crop water demand (ET0 {reference_et0_7day:.1f} mm). "
            "Increase irrigation in short morning intervals and verify root-zone moisture before the next cycle."
        )
    if condition == "Waterlogging risk":
        return (
            f"{crop}: Rainfall is running about {net_water_balance_7day:.1f} mm above estimated demand over 7 days. "
            "Delay irrigation for 2-3 days and improve field drainage to avoid root stress."
        )
    if condition == "Healthy canopy":
        return (
            f"{crop}: Maintain the current schedule. Forecast rainfall is {precipitation_7day:.1f} mm and estimated crop water demand is "
            f"{estimated_crop_water_need_7day:.1f} mm for the next 7 days."
        )
    return (
        f"{crop}: Keep regular irrigation but adjust using the 7-day water balance of {net_water_balance_7day:.1f} mm "
        f"(rainfall {precipitation_7day:.1f} mm vs ET-driven demand {estimated_crop_water_need_7day:.1f} mm)."
    )


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/analyze-field", response_model=AnalyzeResponse)
def analyze_field(payload: AnalyzeRequest) -> AnalyzeResponse:
    if payload.selected_crop and len(payload.selected_crop.strip()) == 0:
        raise HTTPException(status_code=400, detail="selected_crop cannot be empty")

    polygon = _validate_polygon(payload.polygon)
    latitude = payload.latitude
    longitude = payload.longitude

    if polygon is not None:
        centroid = _centroid_from_polygon(polygon)
        if centroid is not None:
            latitude, longitude = centroid

    earth_engine_ready, diagnostic = _earth_engine_diagnostic()
    ndvi = _compute_ndvi_mean(latitude, longitude, polygon) if earth_engine_ready else None
    precipitation_7day, reference_et0_7day = _fetch_weather_summary(latitude, longitude)
    detected_crop, confidence = _detect_crop_from_ndvi(ndvi)
    preferred_crop = payload.selected_crop or detected_crop
    estimated_crop_water_need_7day = _estimated_crop_water_need_7day(
        preferred_crop,
        reference_et0_7day,
    )
    net_water_balance_7day = precipitation_7day - estimated_crop_water_need_7day

    condition = _condition_from_signals(ndvi, precipitation_7day, net_water_balance_7day)
    advice = _recommendation(
        condition,
        preferred_crop,
        precipitation_7day,
        reference_et0_7day,
        estimated_crop_water_need_7day,
        net_water_balance_7day,
    )

    return AnalyzeResponse(
        detected_crop=detected_crop,
        confidence=confidence,
        ndvi=ndvi,
        precipitation_7day_mm=precipitation_7day,
        reference_et0_7day_mm=reference_et0_7day,
        estimated_crop_water_need_7day_mm=estimated_crop_water_need_7day,
        net_water_balance_7day_mm=net_water_balance_7day,
        field_condition=condition,
        recommendation=advice,
        earth_engine_ready=earth_engine_ready,
        diagnostic=diagnostic,
    )


@app.get("/ee-tiles", response_model=EETilesResponse)
def ee_tiles(latitude: float, longitude: float, layer: str = "true_color") -> EETilesResponse:
    if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
        raise HTTPException(status_code=400, detail="Invalid latitude or longitude")

    normalized_layer = layer.strip().lower()
    if normalized_layer not in {"true_color", "ndvi"}:
        raise HTTPException(status_code=400, detail="layer must be true_color or ndvi")

    url_template = _build_ee_tile_url(latitude, longitude, normalized_layer)
    return EETilesResponse(layer=normalized_layer, url_template=url_template)


if __name__ == "__main__":
    import uvicorn

    # Default to 8001 for local runs to avoid frequent conflicts on 8000.
    port = int(os.getenv("BACKEND_PORT", "8001"))
    uvicorn.run(app, host="0.0.0.0", port=port)
