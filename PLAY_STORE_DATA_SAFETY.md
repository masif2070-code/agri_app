# Agrology - Play Console Data Safety Checklist

This document maps the app's actual behavior to Google Play Console Data Safety answers.

---

## 1. App Access & Permissions

### Does your app access any of these sensitive permissions?

- **Location (precise)**: YES
  - Permission name: `android.permission.ACCESS_FINE_LOCATION`
  - Used for: Auto-detecting user's province to customize crop recommendations and weather data
  - When collected: Only when user explicitly taps "Use phone location" or opens map picker
  - Shared: YES (sent to backend for weather and crop analysis)

- **Location (approximate)**: YES
  - Permission name: `android.permission.ACCESS_COARSE_LOCATION`
  - Used for: Fallback coarse location detection
  - When collected: Same as precise location
  - Shared: YES (same backend)

- **Internet**: YES
  - Used for: Weather API calls (open-meteo.com), GIS analysis (backend), map tiles, URL launching
  - Shared: YES (to external weather APIs and your backend)

- **Camera, Microphone, Contacts, SMS, Contacts, Calendar**: NO
- **Background location**: NO (only foreground)

---

## 2. Data Safety Form: Data Collection & Sharing

### Types of data collected by this app:

| Data Type | Collected | Shared | Reason |
|-----------|-----------|--------|--------|
| Precise location | YES | YES | Province detection, weather, crop analysis |
| Approximate location | YES | YES | Fallback province detection |
| Crop selection | YES | YES | Backend analysis, personalization |
| Weather data | YES | NO | Local processing only |
| Field polygon (boundary) | YES | YES | GIS field analysis |
| Growth stage (Wheat) | YES | YES | Crop-specific recommendations |
| Previous irrigations count | YES | YES | Irrigation scheduling |
| Language preference | NO | NO | Local app state only |
| UI state (dropdowns, expansions) | NO | NO | Local app state only |
| Device info | NO | NO | Not collected |
| User ID / Account | NO | NO | No authentication |

### First-party data sharing:

The app shares the following **with your backend** (defined in `lib/main.dart`):
- Latitude, longitude
- Selected crop name
- Growth stage (if Wheat)
- Previous irrigation count
- Field polygon points (if map boundary drawn)

**Backend endpoint**: `https://agri-app-backend-6kyx.onrender.com/analyze-field`

### Third-party data sharing:

The app communicates with:
1. **open-meteo.com** (Weather API)
   - Data: Latitude, longitude
   - Purpose: 7-day weather forecast
   - No identifiable info sent

2. **openstreetmap.org** (Map tiles)
   - Data: None (tiles are fetched by lat/lon in URL, public data)
   - Purpose: Map display

3. **earth.google.com** (Earth Engine via backend proxy)
   - Data: Processed through your backend
   - Purpose: NDVI and satellite analysis

Directly from app: **No** (weather calls go to open-meteo public API, not through your backend)

---

## 3. Data Safety: Specific Form Answers

### Does your app collect, use, or share personal data?

**Answer: YES**

### Data types your app collects:

Select each that applies:

- [ ] Contacts
- [ ] Call history
- [ ] SMS or MMS
- [ ] Email address
- [x] **Precise location** → Reason: "App functionality" (Province auto-detection, weather, crop recommendations)
- [x] **Approximate location** → Reason: "App functionality"
- [x] **User IDs** → Actually: NO (but if forced, the app generates no persistent user ID)
- [ ] Financial info
- [ ] Health info
- [ ] Photos or videos
- [ ] Audio files
- [ ] Files and docs
- [ ] Calendar info
- [ ] Contacts
- [x] **Other data types** → "Crop selection, growth stage, irrigation history" → Reason: "App functionality"

### Data is shared with:

Select what applies:

- [x] **Your own services/backend**
  - Data types: Location (lat/lon), crop selection, field boundary, growth stage, irrigation count
  - Why: Disease / pest detection, crop water need analysis, irrigation recommendations
  - User control: User chooses when to enter location and analyze; toggles between data input options

- [x] **Service providers** (if Earth Engine used)
  - Data types: Location (indirect through backend)
  - Why: Satellite imagery analysis
  - User control: Optional GIS feature (user presses "Analyze Field" button)

- [ ] Other third parties for marketing / advertising
- [ ] Sale of personal data

### Data retention:

**How long is data kept?**

- Location data: **Processed in-memory, not persisted** on device. If sent to backend, backend retention policy applies (you decide).
- Crop/field data: **Not persisted** in the app itself. Each session starts fresh.
- User has control: Can clear all data by reinstalling or clearing app data.

---

## 4. Data Safety: Security Practices

### Does your app use secure transmission?

**Answer: YES**

- [ ] App does NOT use encryption for data in transit
- [x] **App uses HTTPS** for all backend communication (`https://agri-app-backend...`)
- [x] **App uses HTTPS** for all external API calls (open-meteo.com, openstreetmap.org)

### Is sensitive data encrypted on device?

**Answer: NO**

- The app does not persist sensitive data on the device.
- Weather, location, crop selections exist only in active memory during a session.
- User credentials or tokens: NOT USED (no authentication required).

### Security updates and practices:

- App uses Flutter framework (regularly security patched)
- Backend is on Render (they handle server security)
- No hardcoded API keys in app; backend validates API calls
- Data transmission encrypted (HTTPS)

---

## 5. Data Safety: Data Purpose & Use

### How is data used?

1. **Location data (Precise + Approximate)**
   - Purpose: Auto-detect province for crop recommendations
   - Purpose: Fetch weather data specific to user location
   - Purpose: Allow user to analyze field on map
   - **NOT used for**: Tracking, advertising, profile building, cross-app tracking
   - User control: Optional ("Use phone location" button); user must grant permission

2. **Crop and field data**
   - Purpose: Provide irrigation schedule and disease/pest guidance
   - Purpose: Analyze satellite imagery (if GIS feature used)
   - **NOT used for**: Advertising, automated decision-making, selling data
   - User control: User enters crop; user draws boundary on map optional

3. **Weather data**
   - Purpose: Calculate irrigation recommendations
   - **NOT used for**: Any third-party sharing; local processing only

### What about data deletion?

- User can delete all app data: Settings > Apps > Agrology > Storage > Clear Data
- No backend database tied to user identity (each API call is stateless)
- If backend logs API calls: Advise users to assume logs retained per backend's policy

---

## 6. Data Safety: Restricted Use

### Does your app use any restricted data?

- [ ] Health data for any purpose other than health/medical
- [ ] Financial data for any purpose other than finance
- [ ] Precise location for any purpose other than current feature
- [ ] Contacts data (not used at all)
- [ ] Device ID (not used at all)
- [ ] Approximate location for any purpose other than current feature
- [x] **Precise and approximate location for precision agriculture and weather**: YES (explicitly allowed)

---

## 7. Advertising

### Does your app use ads?

**Answer: NO**

- [ ] Google AdMob
- [ ] Third-party ad networks
- No ads of any kind

### Advertising/Analytics tracking:

- [ ] Google Analytics
- [ ] Firebase Analytics
- [ ] Crashlytics (no crash reporting set up)
- [ ] Third-party analytics

All NO.

---

## 8. Content Rating

When you fill out the content rating questionnaire:

- **Violence**: None
- **Sexual content**: None
- **Language**: May include agricultural terminology in Urdu; no profanity
- **Alcohol, tobacco, drugs**: None
- **Gambling**: None
- **Ads**: None
- **Parental guidance**: Not required (app is all-ages)

---

## 9. App Access Declaration

### Does your app require access to restricted functions?

Select if applicable:

- [x] **Location services** (Precise)
  - Justification: "Auto-detect user province for weather and crop guidance. User grants permission on demand via system prompt."

- [x] **Location services** (Approximate)
  - Justification: "Fallback coarse location if fine permission denied."

- [ ] Device IDs (ADVERTISING_ID, etc.)
- [ ] Phone state
- [ ] SMS
- [ ] Call log
- [ ] Calendar
- [ ] Contacts

---

## 10. Privacy Policy Template

You must provide a privacy policy URL. Here is a template:

```
PRIVACY POLICY
Agrology App

Last updated: April 2026

1. INFORMATION WE COLLECT

The app collects:
- Your precise and approximate location (when you grant permission)
- Your crop selection
- Your field boundary (if you draw it on the map)
- Irrigation history you enter
- Your preferred language

2. INFORMATION WE SHARE

Your location and crop data are shared with our backend server 
(https://agri-app-backend-6kyx.onrender.com) to provide:
- Province-specific crop recommendations
- Weather forecasts
- Field analysis using satellite imagery

Your location data may also be shared with:
- Open-Meteo (weather data provider)
- Google Earth Engine (via backend proxy for satellite analysis)

We do not sell your data to third parties.

3. HOW WE USE YOUR DATA

We use your data to:
- Auto-detect your province based on location
- Provide weather-based irrigation guidance
- Recommend crops and pest management practices
- Analyze your field using satellite imagery (optional)

4. DATA RETENTION

- Location data is NOT stored on your device after each session
- Crop and field data are temporary (reset when you exit the app)
- Your backend may retain API logs per its own policy

5. YOUR PRIVACY RIGHTS

You can:
- Refuse location permission (app still works with manual input)
- Deny camera/microphone access (not used by this app)
- Delete app data at any time via Settings > Apps > Agrology > Storage > Clear Data

6. CONTACT US

For privacy questions: [YOUR EMAIL]
```

---

## 11. Target Audience

When playstore asks "Target audience":

- [ ] Children (under 13)
- [x] **Teenagers & Adults**
  - This app requires location permission and sends data to external servers
  - Parental consent not required (no child data collection)

---

## 12. Roll-Out Plan

**Before Production Release:**

1. [ ] Add privacy policy URL to Play Console store listing
2. [ ] Fill in all Data Safety form answers above
3. [ ] Ensure app icon, screenshots, and short/long descriptions are complete
4. [ ] Get feature graphic (1024x500px)
5. [ ] Add 2-4 phone screenshots showing:
   - Language selection
   - Weather/crop section
   - Location prompt
   - Auto-detected province and season
6. [ ] Add release notes for version 1.0.1
7. [ ] Review all content rating answers
8. [ ] Submit for review (usually 2-4 hours for first release)

---

## 13. Common Play Store Rejection Reasons & Prevention

| Risk | Prevention |
|------|-----------|
| Location usage not transparent | Explain location in app description; show permission prompt before use |
| Missing privacy policy | Add privacy policy URL to store listing |
| Unclear data sharing | Data Safety form must clearly list backend sharing |
| No consent before collection | App uses system location permission (user grants/denies) |
| Third-party tracking | Confirm no Google Analytics / Firebase enabled (double-check pubspec.yaml) |

---

## 14. Backend Considerations (for your server)

If you run the backend, ensure:

1. **Privacy Policy on backend** (if you run a website)
   - Must match the app's privacy policy
   - State how long you log API calls

2. **HTTPS only** (already configured: https://...)

3. **CORS headers** (backend allows Flutter app requests)

4. **Data logging**
   - If you log lat/lon + crop + field data for debugging:
     - Disclose in privacy policy
     - Implement log rotation / deletion

5. **Terms of Service**
   - Optional, but recommended for first commercial release

---

## 15. Submission Checklist

- [ ] Version bumped to 1.0.1 (done: pubspec.yaml)
- [ ] AAB built and ready: `build/app/outputs/bundle/release/app-release.aab`
- [ ] Play Console app created
- [ ] Store listing completed (title, short desc, full desc, category)
- [ ] Icon uploaded (512x512 PNG)
- [ ] Feature graphic uploaded (1024x500 PNG)
- [ ] 3+ screenshots uploaded
- [ ] Content rating filled
- [ ] Privacy policy URL added
- [ ] Data Safety form completed (use answers above)
- [ ] Target audience set to "Teenagers & Adults"
- [ ] App access declaration reviewed
- [ ] Release notes added
- [ ] Production release created and AAB uploaded
- [ ] Review submitted

---

## Summary

**For the Play Console Data Safety Form:**

✅ **App collects**: Location, crop selection, field boundary, growth stage, irrigation count  
✅ **Shared with**: Your backend (analyze-field endpoint)  
✅ **Also shared with**: Open-Meteo (weather API), Earth Engine (GIS)  
✅ **Security**: HTTPS encryption, no persistent storage of sensitive data on device  
✅ **Ads**: None  
✅ **Analytics/Crashlytics**: None  
✅ **Privacy Policy**: Required (use template above)  
✅ **User Control**: Location optional, all features accessible without permission  

Your app is low-risk for Play Store rejection if all Data Safety answers match this document.
