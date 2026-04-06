from __future__ import annotations

import math
import os
import time
import uuid
from io import BytesIO
from datetime import date, timedelta
from typing import Any
import xml.etree.ElementTree as ET

import requests
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, ImageFilter, ImageStat
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
    growth_stage: str | None = None
    previous_irrigations_count: int | None = Field(default=None, ge=0, le=12)
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
    weather_diagnostic: str | None = None


class EETilesResponse(BaseModel):
    layer: str
    url_template: str


class CropPhotoRecommendationResponse(BaseModel):
    selected_crop: str
    concern_type: str
    fertilizer_history: str
    model_label: str
    model_confidence: float
    model_version: str
    possible_issue: str
    recommendation: str
    review_case_id: str
    review_status: str
    review_message: str
    confidence_note: str
    next_steps: list[str]
    disclaimer: str


class CropPhotoCaseStatusResponse(BaseModel):
    review_case_id: str
    selected_crop: str
    concern_type: str
    review_status: str
    recommendation: str
    reviewer_notes: str


class CropPhotoCaseReviewRequest(BaseModel):
    recommendation: str = Field(..., min_length=10)
    reviewer_notes: str = ""


class FarmerHeadlineItem(BaseModel):
    title_en: str
    title_ur: str
    source: str
    url: str


class FarmerHeadlinesResponse(BaseModel):
    plant_headlines: list[FarmerHeadlineItem]
    animal_headlines: list[FarmerHeadlineItem]


class CommodityPriceItem(BaseModel):
    commodity_key: str
    title_en: str
    title_ur: str
    unit_en: str
    unit_ur: str
    price_pkr: float
    note_en: str
    note_ur: str


class CommodityPricesResponse(BaseModel):
    market_region_en: str
    market_region_ur: str
    updated_on: str
    source_note_en: str
    source_note_ur: str
    disclaimer_en: str
    disclaimer_ur: str
    items: list[CommodityPriceItem]


# Cache tile URL templates for nearby points to reduce repeated EE map-id calls.
_EE_TILE_CACHE: dict[str, tuple[date, str]] = {}
_EE_TILE_CACHE_TTL_DAYS = 1
_WEATHER_SUMMARY_CACHE: dict[str, tuple[date, float, float]] = {}
_REVIEW_CASES: dict[str, dict[str, Any]] = {}
_WHEAT_STAGE_SEQUENCE: list[tuple[str, str, int]] = [
    ("pre_sowing", "pre-sowing", 0),
    ("crown_root_initiation", "crown root initiation", 1),
    ("tillering", "tillering", 2),
    ("jointing", "jointing / booting", 3),
    ("grain_filling", "grain filling", 4),
]
_FARMER_HEADLINES_FALLBACK: dict[str, list[dict[str, str]]] = {
    "plant_headlines": [
        {
            "title_en": "Punjab trials report better wheat stand with late-autumn seed treatment protocol.",
            "title_ur": "پنجاب ٹرائلز: خزاں کے آخر میں بیج ٹریٹمنٹ سے گندم کا اگاؤ بہتر رپورٹ ہوا۔",
            "source": "PARC / NARC Updates",
            "url": "https://parc.gov.pk/",
        },
        {
            "title_en": "Recent rice studies highlight alternate wetting and drying to save water without major yield loss.",
            "title_ur": "حالیہ دھان تحقیق: وقفے وقفے سے آبپاشی سے پانی کی بچت، پیداوار میں نمایاں کمی کے بغیر۔",
            "source": "IRRI Research",
            "url": "https://www.irri.org/news-and-events",
        },
        {
            "title_en": "Integrated pest monitoring advisories stress field scouting before pesticide application.",
            "title_ur": "مربوط پیسٹ مانیٹرنگ ہدایات: اسپرے سے پہلے کھیت کی باقاعدہ اسکاوٹنگ پر زور۔",
            "source": "FAO Crop News",
            "url": "https://www.fao.org/newsroom/en/",
        },
    ],
    "animal_headlines": [
        {
            "title_en": "New dairy nutrition findings emphasize balanced mineral mix during heat stress periods.",
            "title_ur": "ڈیری غذائیت کی نئی تحقیق: گرمی کے دباؤ میں متوازن منرل مکس کی اہمیت نمایاں۔",
            "source": "ILRI News",
            "url": "https://www.ilri.org/news",
        },
        {
            "title_en": "Field reports show timely deworming and vaccination improve young stock survival.",
            "title_ur": "فیلڈ رپورٹس: بروقت ڈی ورمنگ اور ویکسینیشن سے کم عمر جانوروں کی بقا بہتر۔",
            "source": "FAO Livestock",
            "url": "https://www.fao.org/livestock/en/",
        },
        {
            "title_en": "Poultry management research recommends stronger ventilation control in seasonal humidity.",
            "title_ur": "پولٹری مینجمنٹ تحقیق: موسمی نمی میں بہتر وینٹیلیشن کنٹرول کی سفارش۔",
            "source": "Poultry World",
            "url": "https://www.poultryworld.net/",
        },
    ],
}
_FARMER_HEADLINES_FEEDS: dict[str, list[dict[str, str]]] = {
    "plant_headlines": [
        {
            "source": "Google News - Crop Research",
            "url": "https://news.google.com/rss/search?q=crop+research+agriculture&hl=en-PK&gl=PK&ceid=PK:en",
        },
        {
            "source": "Google News - Plant Disease",
            "url": "https://news.google.com/rss/search?q=plant+disease+management+farming&hl=en-PK&gl=PK&ceid=PK:en",
        },
    ],
    "animal_headlines": [
        {
            "source": "Google News - Livestock Research",
            "url": "https://news.google.com/rss/search?q=livestock+research+dairy+farming&hl=en-PK&gl=PK&ceid=PK:en",
        },
        {
            "source": "Google News - Poultry Health",
            "url": "https://news.google.com/rss/search?q=poultry+health+research&hl=en-PK&gl=PK&ceid=PK:en",
        },
    ],
}
_FARMER_HEADLINES_CACHE: dict[str, list[dict[str, str]]] = {
    "plant_headlines": list(_FARMER_HEADLINES_FALLBACK["plant_headlines"]),
    "animal_headlines": list(_FARMER_HEADLINES_FALLBACK["animal_headlines"]),
}
_FARMER_HEADLINES_LAST_REFRESH: date | None = None
_COMMODITY_PRICES: list[dict[str, Any]] = [
    {
        "commodity_key": "urea_bag",
        "title_en": "Urea Fertilizer Bag",
        "title_ur": "یوریا کھاد بیگ",
        "unit_en": "Per 50 kg bag",
        "unit_ur": "فی 50 کلو بیگ",
        "price_pkr": 4500,
        "note_en": "Indicative dealer retail range",
        "note_ur": "اشاریہ ڈیلر ریٹیل رینج",
    },
    {
        "commodity_key": "dap_bag",
        "title_en": "DAP Fertilizer Bag",
        "title_ur": "ڈی اے پی کھاد بیگ",
        "unit_en": "Per 50 kg bag",
        "unit_ur": "فی 50 کلو بیگ",
        "price_pkr": 12500,
        "note_en": "Indicative dealer retail range",
        "note_ur": "اشاریہ ڈیلر ریٹیل رینج",
    },
    {
        "commodity_key": "wheat_40kg",
        "title_en": "Wheat",
        "title_ur": "گندم",
        "unit_en": "Per 40 kg",
        "unit_ur": "فی 40 کلو",
        "price_pkr": 3100,
        "note_en": "Approx mandi spot value",
        "note_ur": "تقریبی منڈی اسپاٹ ویلیو",
    },
    {
        "commodity_key": "rice_40kg",
        "title_en": "Rice",
        "title_ur": "چاول",
        "unit_en": "Per 40 kg",
        "unit_ur": "فی 40 کلو",
        "price_pkr": 7200,
        "note_en": "Approx quality-mix mandi value",
        "note_ur": "تقریبی معیار کے ملاپ کی منڈی ویلیو",
    },
    {
        "commodity_key": "gold_tola",
        "title_en": "Gold",
        "title_ur": "سونا",
        "unit_en": "Per tola",
        "unit_ur": "فی تولہ",
        "price_pkr": 338000,
        "note_en": "Approx bullion market reference",
        "note_ur": "تقریبی بلین مارکیٹ حوالہ",
    },
]


def _rss_items(url: str, source: str, limit: int = 4) -> list[dict[str, str]]:
    try:
        response = requests.get(
            url,
            timeout=10,
            headers={"User-Agent": "Mozilla/5.0 (compatible; AgriAppBot/1.0)"},
        )
        response.raise_for_status()

        root = ET.fromstring(response.content)
        items: list[dict[str, str]] = []
        for node in root.findall("./channel/item"):
            title = (node.findtext("title") or "").strip()
            link = (node.findtext("link") or "").strip()
            if not title or not link:
                continue
            items.append(
                {
                    "title_en": title,
                    "title_ur": title,
                    "source": source,
                    "url": link,
                }
            )
            if len(items) >= limit:
                break
        return items
    except Exception:
        return []


def _merge_unique_headlines(headlines: list[dict[str, str]], limit: int = 4) -> list[dict[str, str]]:
    deduped: list[dict[str, str]] = []
    seen_titles: set[str] = set()
    seen_urls: set[str] = set()
    for item in headlines:
        title_key = item.get("title_en", "").strip().lower()
        url_key = item.get("url", "").strip().lower()
        if not title_key or not url_key:
            continue
        if title_key in seen_titles or url_key in seen_urls:
            continue
        seen_titles.add(title_key)
        seen_urls.add(url_key)
        deduped.append(item)
        if len(deduped) >= limit:
            break
    return deduped


def _refresh_farmer_headlines(force_refresh: bool = False) -> None:
    global _FARMER_HEADLINES_LAST_REFRESH

    today = date.today()
    if not force_refresh and _FARMER_HEADLINES_LAST_REFRESH == today:
        return

    refreshed_plant: list[dict[str, str]] = []
    refreshed_animal: list[dict[str, str]] = []

    for feed in _FARMER_HEADLINES_FEEDS["plant_headlines"]:
        refreshed_plant.extend(_rss_items(feed["url"], feed["source"]))

    for feed in _FARMER_HEADLINES_FEEDS["animal_headlines"]:
        refreshed_animal.extend(_rss_items(feed["url"], feed["source"]))

    refreshed_plant = _merge_unique_headlines(refreshed_plant, limit=4)
    refreshed_animal = _merge_unique_headlines(refreshed_animal, limit=4)

    _FARMER_HEADLINES_CACHE["plant_headlines"] = (
        refreshed_plant
        if refreshed_plant
        else list(_FARMER_HEADLINES_FALLBACK["plant_headlines"])
    )
    _FARMER_HEADLINES_CACHE["animal_headlines"] = (
        refreshed_animal
        if refreshed_animal
        else list(_FARMER_HEADLINES_FALLBACK["animal_headlines"])
    )
    _FARMER_HEADLINES_LAST_REFRESH = today


def _weather_cache_key(latitude: float, longitude: float) -> str:
    # ~100m precision is enough for weather reuse and reduces upstream calls.
    return f"{round(latitude, 3)}:{round(longitude, 3)}"


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


def _climate_fallback_weather(latitude: float) -> tuple[float, float]:
    today = date.today()
    day_of_year = today.timetuple().tm_yday

    # Seasonal mean/range approximation tuned for Punjab-like subtropical climate.
    seasonal_temperature_mean = 23.0 + 9.0 * math.sin((2 * math.pi / 365) * (day_of_year - 170))
    seasonal_temperature_range = 11.0 + 1.5 * math.cos((2 * math.pi / 365) * (day_of_year - 200))

    et0_7day = 0.0
    for offset in range(7):
        d = today + timedelta(days=offset)
        et0_7day += _estimate_daily_et0_hargreaves(
            latitude,
            d,
            seasonal_temperature_mean + seasonal_temperature_range / 2,
            seasonal_temperature_mean - seasonal_temperature_range / 2,
        )

    # Very simple monthly rainfall climatology fallback (mm/day) for Punjab region.
    monthly_mm_per_day = {
        1: 0.8,
        2: 1.0,
        3: 1.4,
        4: 1.2,
        5: 0.7,
        6: 1.0,
        7: 3.8,
        8: 4.0,
        9: 2.1,
        10: 0.6,
        11: 0.4,
        12: 0.6,
    }
    precipitation_7day = 7.0 * monthly_mm_per_day.get(today.month, 1.0)
    return precipitation_7day, et0_7day


def _fetch_weather_summary(latitude: float, longitude: float) -> tuple[float, float, str | None]:
    cache_key = _weather_cache_key(latitude, longitude)
    cached = _WEATHER_SUMMARY_CACHE.get(cache_key)
    if cached is not None:
        cached_on, cached_precip, cached_et0 = cached
        if cached_on == date.today():
            return cached_precip, cached_et0, None

    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={latitude}&longitude={longitude}"
        "&daily=precipitation_sum,et0_fao_evapotranspiration,temperature_2m_max,temperature_2m_min"
        "&timezone=Asia%2FKarachi"
    )
    try:
        response = None
        for attempt in range(3):
            response = requests.get(url, timeout=10)
            if response.status_code != 429:
                break
            if attempt < 2:
                time.sleep(1.0 * (attempt + 1))

        assert response is not None
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
        _WEATHER_SUMMARY_CACHE[cache_key] = (date.today(), precipitation_7day, et0_7day)
        return precipitation_7day, et0_7day, None
    except Exception as exc:
        if cached is not None:
            cached_on, cached_precip, cached_et0 = cached
            return (
                cached_precip,
                cached_et0,
                f"Using cached weather from {cached_on.isoformat()} due to upstream error: {exc}",
            )

        fallback_precip, fallback_et0 = _climate_fallback_weather(latitude)
        return (
            fallback_precip,
            fallback_et0,
            f"Using climate fallback due to upstream error: {exc}",
        )


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


def _normalize_wheat_growth_stage(growth_stage: str | None) -> str:
    if not growth_stage:
        return "crown_root_initiation"

    normalized = growth_stage.strip().lower().replace("-", "_").replace(" ", "_")
    aliases = {
        "cri": "crown_root_initiation",
        "crown_root": "crown_root_initiation",
        "crown_root_initiation": "crown_root_initiation",
        "booting": "jointing",
        "heading": "jointing",
        "jointing_booting": "jointing",
        "grain_fill": "grain_filling",
    }
    return aliases.get(normalized, normalized)


def _wheat_stage_details(growth_stage: str | None) -> tuple[str, str, int, str | None]:
    normalized = _normalize_wheat_growth_stage(growth_stage)
    for index, (stage_key, stage_label, irrigation_number) in enumerate(_WHEAT_STAGE_SEQUENCE):
        if stage_key == normalized:
            next_stage = None
            if index + 1 < len(_WHEAT_STAGE_SEQUENCE):
                next_stage = _WHEAT_STAGE_SEQUENCE[index + 1][1]
            return stage_key, stage_label, irrigation_number, next_stage
    return _wheat_stage_details("crown_root_initiation")


def _wheat_recommendation(
    precipitation_7day: float,
    reference_et0_7day: float,
    estimated_crop_water_need_7day: float,
    net_water_balance_7day: float,
    growth_stage: str | None,
    previous_irrigations_count: int | None,
) -> str:
    _, stage_label, target_irrigation_number, next_stage = _wheat_stage_details(growth_stage)
    previous_irrigations = max(previous_irrigations_count or 0, 0)
    balance_text = (
        f"Forecast rainfall is {precipitation_7day:.1f} mm against about "
        f"{estimated_crop_water_need_7day:.1f} mm demand (ET0 {reference_et0_7day:.1f} mm), "
        f"leaving a {net_water_balance_7day:.1f} mm 7-day water balance."
    )

    if target_irrigation_number == 0:
        if net_water_balance_7day <= -10:
            return (
                f"Wheat at {stage_label}: You reported {previous_irrigations} previous irrigations. "
                f"Give a pre-sowing irrigation now so the seedbed is uniformly moist before planting. {balance_text}"
            )
        return (
            f"Wheat at {stage_label}: You reported {previous_irrigations} previous irrigations. "
            "Hold pre-sowing irrigation for the moment if the seedbed is already workable, and reassess after the next rainfall update. "
            f"{balance_text}"
        )

    if previous_irrigations < target_irrigation_number:
        if net_water_balance_7day <= -12:
            advice = (
                f"Wheat at {stage_label}: You reported {previous_irrigations} previous irrigations, so irrigation "
                f"#{target_irrigation_number} is due now. {balance_text}"
            )
        elif net_water_balance_7day <= 5:
            advice = (
                f"Wheat at {stage_label}: You reported {previous_irrigations} previous irrigations, so irrigation "
                f"#{target_irrigation_number} should be scheduled within 1-3 days unless the root zone is already moist. {balance_text}"
            )
        else:
            advice = (
                f"Wheat at {stage_label}: This stage normally needs irrigation #{target_irrigation_number}, but the current forecast can cover part of the demand. "
                f"Delay for 2-3 days and recheck soil moisture before irrigating. {balance_text}"
            )
        if next_stage is not None:
            advice += f" The next key irrigation after this stage is usually at {next_stage}."
        return advice

    if previous_irrigations == target_irrigation_number:
        advice = (
            f"Wheat at {stage_label}: You have already completed the usual irrigation count for this stage ({previous_irrigations}). "
            "Do not repeat irrigation immediately; confirm moisture in the top 45-60 cm before applying more water. "
            f"{balance_text}"
        )
        if next_stage is not None:
            advice += f" The next planned irrigation is usually at {next_stage}."
        return advice

    return (
        f"Wheat at {stage_label}: You reported {previous_irrigations} irrigations, which is already above the usual count for this stage "
        f"({target_irrigation_number}). Hold irrigation for now, watch for lodging or waterlogging, and only irrigate again if the field dries below the root zone. "
        f"{balance_text}"
    )


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
    growth_stage: str | None = None,
    previous_irrigations_count: int | None = None,
) -> str:
    if crop == "Wheat":
        return _wheat_recommendation(
            precipitation_7day,
            reference_et0_7day,
            estimated_crop_water_need_7day,
            net_water_balance_7day,
            growth_stage,
            previous_irrigations_count,
        )

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


def _normalize_concern_type(concern_type: str) -> str:
    normalized = concern_type.strip().lower().replace("-", "_").replace(" ", "_")
    allowed = {"nutrient_deficiency", "insect_pests", "disease"}
    if normalized in allowed:
        return normalized
    return "nutrient_deficiency"


def _analyze_crop_image_signals(photo_bytes: bytes) -> dict[str, float]:
    try:
        image = Image.open(BytesIO(photo_bytes)).convert("RGB")
    except Exception:
        return {
            "yellow_ratio": 0.0,
            "brown_ratio": 0.0,
            "green_ratio": 0.0,
            "dark_spot_ratio": 0.0,
            "edge_intensity": 0.0,
        }

    image.thumbnail((256, 256))
    pixels = list(image.getdata())
    if not pixels:
        return {
            "yellow_ratio": 0.0,
            "brown_ratio": 0.0,
            "green_ratio": 0.0,
            "dark_spot_ratio": 0.0,
            "edge_intensity": 0.0,
        }

    total = float(len(pixels))
    yellow_count = 0
    brown_count = 0
    green_count = 0
    dark_spot_count = 0

    for r, g, b in pixels:
        if r > 120 and g > 100 and b < 130 and abs(r - g) < 60:
            yellow_count += 1
        if r > 95 and g > 50 and b < 80 and r > g * 1.03:
            brown_count += 1
        if g > 60 and g > r * 1.05 and g > b * 1.05:
            green_count += 1
        if r < 70 and g < 70 and b < 70:
            dark_spot_count += 1

    edge_image = image.convert("L").filter(ImageFilter.FIND_EDGES)
    edge_mean = ImageStat.Stat(edge_image).mean[0] / 255.0

    return {
        "yellow_ratio": yellow_count / total,
        "brown_ratio": brown_count / total,
        "green_ratio": green_count / total,
        "dark_spot_ratio": dark_spot_count / total,
        "edge_intensity": max(0.0, min(1.0, edge_mean)),
    }


def _feature_vector_from_signals(image_signals: dict[str, float]) -> tuple[float, ...]:
    return (
        image_signals.get("yellow_ratio", 0.0),
        image_signals.get("brown_ratio", 0.0),
        image_signals.get("green_ratio", 0.0),
        image_signals.get("dark_spot_ratio", 0.0),
        image_signals.get("edge_intensity", 0.0),
    )


def _predict_issue_with_model(
    image_signals: dict[str, float],
    concern_type: str,
) -> tuple[str, float, str]:
    # Lightweight prototype classifier over engineered leaf features.
    # Model version is explicit so we can upgrade/compare in future.
    model_version = "signal-prototype-v1"
    concern = _normalize_concern_type(concern_type)
    x = _feature_vector_from_signals(image_signals)

    prototypes: dict[str, tuple[float, ...]] = {
        "nitrogen_deficiency": (0.30, 0.10, 0.32, 0.06, 0.10),
        "potassium_deficiency": (0.18, 0.24, 0.34, 0.08, 0.16),
        "zinc_deficiency": (0.22, 0.08, 0.38, 0.06, 0.20),
        "aphid_or_whitefly": (0.10, 0.10, 0.46, 0.16, 0.18),
        "chewing_pest_damage": (0.08, 0.14, 0.42, 0.14, 0.34),
        "leaf_spot_or_blight": (0.14, 0.26, 0.36, 0.22, 0.26),
        "rust_or_mildew_pattern": (0.20, 0.16, 0.34, 0.18, 0.22),
    }

    allowed_labels = set(prototypes.keys())
    if concern == "nutrient_deficiency":
        allowed_labels = {"nitrogen_deficiency", "potassium_deficiency", "zinc_deficiency"}
    elif concern == "insect_pests":
        allowed_labels = {"aphid_or_whitefly", "chewing_pest_damage"}
    elif concern == "disease":
        allowed_labels = {"leaf_spot_or_blight", "rust_or_mildew_pattern"}

    distances: dict[str, float] = {}
    for label, p in prototypes.items():
        if label not in allowed_labels:
            continue
        distances[label] = math.sqrt(sum((a - b) ** 2 for a, b in zip(x, p, strict=False)))

    if not distances:
        return "unknown", 0.0, model_version

    best_label = min(distances, key=distances.get)
    # Convert distance to bounded confidence. Smaller distance => higher confidence.
    confidence = max(0.25, min(0.95, 1.0 - distances[best_label] * 1.6))
    return best_label, confidence, model_version


def _build_photo_recommendation(
    selected_crop: str,
    concern_type: str,
    notes: str,
    fertilizer_history: str,
    review_case_id: str,
    image_signals: dict[str, float],
) -> CropPhotoRecommendationResponse:
    concern = _normalize_concern_type(concern_type)
    crop = selected_crop.strip() or "Unknown crop"
    notes_lower = notes.lower()

    deficiency_signals = [
        "yellow", "chlorosis", "purple", "stunted", "pale", "burn", "spot",
    ]
    pest_signals = [
        "hole", "chewed", "web", "larva", "worm", "aphid", "whitefly", "thrips",
    ]
    disease_signals = [
        "lesion", "necrosis", "blight", "rust", "mildew", "fungal", "rot", "wilt", "leaf spot",
    ]

    deficiency_score = float(sum(1 for token in deficiency_signals if token in notes_lower))
    pest_score = float(sum(1 for token in pest_signals if token in notes_lower))
    disease_score = float(sum(1 for token in disease_signals if token in notes_lower))

    yellow_ratio = image_signals.get("yellow_ratio", 0.0)
    brown_ratio = image_signals.get("brown_ratio", 0.0)
    green_ratio = image_signals.get("green_ratio", 0.0)
    dark_spot_ratio = image_signals.get("dark_spot_ratio", 0.0)
    edge_intensity = image_signals.get("edge_intensity", 0.0)

    deficiency_score += (yellow_ratio * 6.0) + (brown_ratio * 3.0) + ((1.0 - green_ratio) * 2.0)
    pest_score += (dark_spot_ratio * 4.0) + (edge_intensity * 3.0) + (brown_ratio * 1.5)
    disease_score += (dark_spot_ratio * 5.0) + (brown_ratio * 3.5) + (edge_intensity * 2.0)

    model_label, model_confidence, model_version = _predict_issue_with_model(
        image_signals,
        concern,
    )

    if concern == "nutrient_deficiency":
        possible_issue = "Likely nutrient deficiency pattern"
    elif concern == "insect_pests":
        possible_issue = "Likely insect pest attack pattern"
    else:
        possible_issue = "Likely disease symptoms pattern"

    if model_label in {"nitrogen_deficiency", "potassium_deficiency", "zinc_deficiency"}:
        possible_issue = "Likely nutrient deficiency pattern"
    elif model_label in {"aphid_or_whitefly", "chewing_pest_damage"}:
        possible_issue = "Likely insect pest attack pattern"
    elif model_label in {"leaf_spot_or_blight", "rust_or_mildew_pattern"}:
        possible_issue = "Likely disease symptoms pattern"

    if "zinc" in notes_lower or "strip" in notes_lower:
        issue_hint = "Possible zinc deficiency"
    elif "nitrogen" in notes_lower or "uniform yellow" in notes_lower:
        issue_hint = "Possible nitrogen deficiency"
    elif "potash" in notes_lower or "leaf edge burn" in notes_lower:
        issue_hint = "Possible potassium deficiency"
    elif "aphid" in notes_lower:
        issue_hint = "Possible aphid infestation"
    elif "whitefly" in notes_lower:
        issue_hint = "Possible whitefly infestation"
    elif "worm" in notes_lower or "larva" in notes_lower:
        issue_hint = "Possible caterpillar/borer infestation"
    elif "blight" in notes_lower or "leaf spot" in notes_lower:
        issue_hint = "Possible blight/leaf spot disease"
    elif "rust" in notes_lower or "mildew" in notes_lower:
        issue_hint = "Possible rust or mildew disease"
    else:
        if possible_issue == "Likely nutrient deficiency pattern" and yellow_ratio >= 0.18:
            issue_hint = "Possible nitrogen-related chlorosis pattern"
        elif possible_issue == "Likely nutrient deficiency pattern" and brown_ratio >= 0.14:
            issue_hint = "Possible potassium-related leaf burn pattern"
        elif possible_issue == "Likely insect pest attack pattern" and dark_spot_ratio >= 0.10:
            issue_hint = "Possible sucking pest/spot damage pattern"
        elif possible_issue == "Likely insect pest attack pattern" and edge_intensity >= 0.24:
            issue_hint = "Possible chewing pest damage pattern"
        elif possible_issue == "Likely disease symptoms pattern" and dark_spot_ratio >= 0.15:
            issue_hint = "Possible leaf spot/blight disease pattern"
        elif possible_issue == "Likely disease symptoms pattern" and brown_ratio >= 0.20:
            issue_hint = "Possible necrotic fungal disease pattern"
        else:
            issue_hint = possible_issue

    recommendation = (
        f"For {crop}, start with field scouting in a zig-zag pattern and inspect 20-25 plants. "
        "Record upper and lower leaf symptoms, stem condition, and visible insect or disease signs. "
        f"Since sowing, reported fertilizer use is: {fertilizer_history}. "
        "Check whether symptoms started before or after each fertilizer application to narrow causes. "
        "If deficiency is suspected, verify with soil/leaf test before corrective spray. "
        "If insect attack is suspected, apply integrated pest management: threshold-based action, "
        "targeted pesticide rotation by mode-of-action, and follow label dose and pre-harvest interval. "
        "If disease is suspected, use clean field sanitation, remove heavily infected leaves where feasible, "
        "and apply registered fungicide/bactericide only after confirming diagnosis and crop stage."
    )

    next_steps = [
        "Capture 3-5 clear photos in daylight: whole plant, close leaf, underside of leaf, and stem.",
        "Share field age/stage, exact fertilizer brand/type and dose timeline since sowing, and last spray used.",
        "Confirm diagnosis with local agronomist or extension officer before major chemical use.",
    ]

    return CropPhotoRecommendationResponse(
        selected_crop=crop,
        concern_type=concern,
        fertilizer_history=fertilizer_history,
        model_label=model_label,
        model_confidence=round(model_confidence, 3),
        model_version=model_version,
        possible_issue=issue_hint,
        recommendation=recommendation,
        review_case_id=review_case_id,
        review_status="pending_review",
        review_message="Case submitted for expert verification. Preliminary recommendation shown.",
        confidence_note=(
            "Photo-guided preliminary result based on leaf color/texture signals. "
            f"Yellow={yellow_ratio:.0%}, Brown={brown_ratio:.0%}, Green={green_ratio:.0%}, "
            f"Dark spots={dark_spot_ratio:.0%}. Add crop stage and symptom timeline for higher confidence."
        ),
        next_steps=next_steps,
        disclaimer=(
            "This recommendation is advisory and not a laboratory diagnosis. "
            "Always follow local extension guidance and product labels."
        ),
    )


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/farmer-headlines", response_model=FarmerHeadlinesResponse)
def farmer_headlines(force_refresh: bool = False) -> FarmerHeadlinesResponse:
    _refresh_farmer_headlines(force_refresh=force_refresh)

    return FarmerHeadlinesResponse(
        plant_headlines=[
            FarmerHeadlineItem(**item)
            for item in _FARMER_HEADLINES_CACHE["plant_headlines"]
        ],
        animal_headlines=[
            FarmerHeadlineItem(**item)
            for item in _FARMER_HEADLINES_CACHE["animal_headlines"]
        ],
    )


@app.get("/commodity-prices", response_model=CommodityPricesResponse)
def commodity_prices() -> CommodityPricesResponse:
    return CommodityPricesResponse(
        market_region_en="Pakistan reference markets",
        market_region_ur="پاکستانی ریفرنس مارکیٹس",
        updated_on=date.today().isoformat(),
        source_note_en=(
            "Prices are reference indicators built from mixed market observations and news snapshots."
        ),
        source_note_ur=(
            "قیمتیں ریفرنس اشارے ہیں جو مختلف مارکیٹ مشاہدات اور خبروں کے خلاصوں سے بنائی گئی ہیں۔"
        ),
        disclaimer_en=(
            "Use for planning only. Actual local dealer and mandi rates may differ by date, quality, and city."
        ),
        disclaimer_ur=(
            "صرف منصوبہ بندی کے لیے استعمال کریں۔ حقیقی مقامی ڈیلر اور منڈی ریٹس تاریخ، معیار اور شہر کے حساب سے مختلف ہو سکتے ہیں۔"
        ),
        items=[CommodityPriceItem(**item) for item in _COMMODITY_PRICES],
    )


@app.post("/analyze-field", response_model=AnalyzeResponse)
def analyze_field(payload: AnalyzeRequest) -> AnalyzeResponse:
    if payload.selected_crop and len(payload.selected_crop.strip()) == 0:
        raise HTTPException(status_code=400, detail="selected_crop cannot be empty")
    if payload.growth_stage and len(payload.growth_stage.strip()) == 0:
        raise HTTPException(status_code=400, detail="growth_stage cannot be empty")

    polygon = _validate_polygon(payload.polygon)
    latitude = payload.latitude
    longitude = payload.longitude

    if polygon is not None:
        centroid = _centroid_from_polygon(polygon)
        if centroid is not None:
            latitude, longitude = centroid

    earth_engine_ready, diagnostic = _earth_engine_diagnostic()
    ndvi = _compute_ndvi_mean(latitude, longitude, polygon) if earth_engine_ready else None
    precipitation_7day, reference_et0_7day, weather_diagnostic = _fetch_weather_summary(latitude, longitude)
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
        payload.growth_stage,
        payload.previous_irrigations_count,
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
        weather_diagnostic=weather_diagnostic,
    )


@app.post("/crop-photo-recommendation", response_model=CropPhotoRecommendationResponse)
async def crop_photo_recommendation(
    photo: UploadFile = File(...),
    selected_crop: str = Form(...),
    concern_type: str = Form("nutrient_deficiency"),
    fertilizer_history: str = Form(...),
    notes: str = Form(""),
) -> CropPhotoRecommendationResponse:
    if not photo.filename:
        raise HTTPException(status_code=400, detail="photo filename is missing")

    content = await photo.read()
    if not content:
        raise HTTPException(status_code=400, detail="photo is empty")
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="photo exceeds 10 MB size limit")
    if len(fertilizer_history.strip()) < 3:
        raise HTTPException(
            status_code=400,
            detail="fertilizer_history is required and should describe what was applied since sowing",
        )

    image_signals = _analyze_crop_image_signals(content)
    review_case_id = str(uuid.uuid4())
    response = _build_photo_recommendation(
        selected_crop,
        concern_type,
        notes,
        fertilizer_history.strip(),
        review_case_id,
        image_signals,
    )

    _REVIEW_CASES[review_case_id] = {
        "review_case_id": review_case_id,
        "selected_crop": response.selected_crop,
        "concern_type": response.concern_type,
        "fertilizer_history": response.fertilizer_history,
        "notes": notes.strip(),
        "review_status": "pending_review",
        "recommendation": response.recommendation,
        "reviewer_notes": "",
    }

    return response


@app.get("/crop-photo-cases/{case_id}", response_model=CropPhotoCaseStatusResponse)
def crop_photo_case_status(case_id: str) -> CropPhotoCaseStatusResponse:
    case = _REVIEW_CASES.get(case_id)
    if case is None:
        raise HTTPException(status_code=404, detail="review case not found")

    return CropPhotoCaseStatusResponse(
        review_case_id=case["review_case_id"],
        selected_crop=case["selected_crop"],
        concern_type=case["concern_type"],
        review_status=case["review_status"],
        recommendation=case["recommendation"],
        reviewer_notes=case["reviewer_notes"],
    )


@app.post("/crop-photo-cases/{case_id}/review", response_model=CropPhotoCaseStatusResponse)
def crop_photo_case_review(
    case_id: str,
    payload: CropPhotoCaseReviewRequest,
) -> CropPhotoCaseStatusResponse:
    case = _REVIEW_CASES.get(case_id)
    if case is None:
        raise HTTPException(status_code=404, detail="review case not found")

    case["review_status"] = "reviewed"
    case["recommendation"] = payload.recommendation.strip()
    case["reviewer_notes"] = payload.reviewer_notes.strip()

    return CropPhotoCaseStatusResponse(
        review_case_id=case["review_case_id"],
        selected_crop=case["selected_crop"],
        concern_type=case["concern_type"],
        review_status=case["review_status"],
        recommendation=case["recommendation"],
        reviewer_notes=case["reviewer_notes"],
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
