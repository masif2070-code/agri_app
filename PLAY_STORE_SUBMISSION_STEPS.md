# Play Console Submission Walkthrough for Agrology (1.0.1)

## Quick Links

1. **Play Console**: https://play.google.com/console/
2. **App Release AAB**: `c:\My Data\my app\agri_app\build\app\outputs\bundle\release\app-release.aab`
3. **Data Safety Guide**: See `PLAY_STORE_DATA_SAFETY.md` in this project
4. **Privacy Policy Template**: See `PRIVACY_POLICY_TEMPLATE.md` in this project

---

## Step 1: Create Play Console Account & App

### Prerequisites
- Google account
- Payment method on file (Google charges $25 one-time developer registration fee)

### Actions
1. Go to https://play.google.com/console/
2. Click **"Create App"**
3. Enter:
   - **App name**: `Agrology`
   - **Default language**: Select your preference
   - **App or game**: Select **App**
   - **Free or paid**: Select **Free**
4. Accept Play Console Developer Agreement
5. Click **Create**

### Result
- Play Console dashboard opens for your new app
- Navigate to **Release > Production** (sidebar)

---

## Step 2: Complete Store Listing Metadata

Location: **Store Setup > App Listing**

### Required Fields

#### App icon (512×512 PNG)
- Use: `assets/images/app_icon.png` (or higher resolution version)
- Requirements:
  - PNG or JPEG format
  - Minimum 512×512 pixels
  - No transparent backgrounds for app icon
- Upload location: **App icon** field

#### Short description (max 80 characters)
```
Smart crop guidance, weather alerts, & livestock care for Pakistani farmers.
```

#### Full description (max 4,000 characters)
```
Agrology - Your Complete Agricultural Assistant

Agrology is a free mobile app designed for farmers across Pakistan. 
Get province-specific guidance on crop management, weather-based irrigation 
scheduling, livestock health, and pest management—all in English and Urdu.

FEATURES:
- Crop Database: Browse 15+ crops with region-specific care instructions
- Weather-Based Irrigation: Real-time weather data with personalized scheduling
- Province Detection: Auto-detects your location (Punjab, Sindh, KP, Balochistan, AJK, GB)
- Livestock & Pets: Complete care guides for cattle, goats, sheep, and pet animals
- Offline-Friendly: Core features work without constant internet connection
- Bilingual Support: Full support for English and Urdu

CROPS COVERED:
Field Crops: Wheat, Maize, Rice, Cotton, Sugarcane, Gram, Mustard, Bajra, Barley
Vegetables: Potato, Onion, Tomato, Chilli, Brinjal
Fruits: Mango, Citrus, Guava, Banana

LIVESTOCK COVERED:
- Dairy cattle, beef cattle, sheep, goats, buffalo
- Poultry (chickens, ducks)
- Fisheries basics
- Plus pet care: dogs, cats, birds

GUIDANCE INCLUDES:
- Cultivation practices & regional sowing windows
- Fertilizer management by crop stage
- Disease & pest identification & treatment
- Weed control strategies
- Wheat growth stage irrigation scheduling
- Young animal care protocols
- Vaccination plans
- Common disease treatment plans

LOCATION FEATURES:
- Auto-detect province for tailored recommendations
- Map-based field location selection
- Optional satellite field analysis (NDVI)

ABOUT DATA:
- Location is optional (grant permission or enter coordinates manually)
- Data is sent to our backend for analysis & recommendations
- No ads, no tracking, no data sale
- See our privacy policy for complete details

AVAILABLE LANGUAGES:
- English
- اردو (Urdu)

Download Agrology today and make smarter farming decisions!
```

#### Category
Select: **Productivity** (if available) or **Utilities**

#### Content rating
- You'll need to complete this in next section

#### Screenshots (2–8 required, minimum 2)
Create 1080×1920 PNG/JPG screenshots showing:

**Screenshot 1**: Language selection
- Shows: "Choose Language / زبان منتخب کریں"
- Text overlay: "Select English or Urdu"

**Screenshot 2**: Main crop section
- Shows: Section chooser with Crop (green) and Animal (blue) cards
- Text overlay: "Browse 15+ crops with region-specific guidance"

**Screenshot 3**: Location detection
- Shows: Auto-detected province display
- Text overlay: "Auto-detects your province for tailored recommendations"

**Screenshot 4**: Weather & irrigation
- Shows: Weather data and irrigation schedule
- Text overlay: "Weather-based irrigation scheduling"

Create these as simple graphics or screenshots from your device using:
```powershell
# If you have the app running on Android device:
adb shell screencap -p /sdcard/screenshot_1.png
adb pull /sdcard/screenshot_1.png
```

#### Feature graphic (1024×500 PNG/JPG)
- Design a simple graphic showing:
  - App name "Agrology"
  - Key benefit: "Smart Farm Guidance"
  - Colors: Green (#2E7D32) and light background

#### Content rating questionnaire
Location: **Setup > Content Rating**

Answer the questionnaire:
- **Violence**: None
- **Sexual content**: None
- **Profanity**: None
- **Alcohol, tobacco, drugs**: None
- **Gambling**: None
- **Ads**: No ads
- **Parental controls**: Not applicable
- Click **Save**

---

## Step 3: Upload Privacy Policy

Location: **Setup > App content**

1. Scroll to **Privacy policy**
2. Enter URL or text:
   - **Option A (Recommended)**: Host the policy on a website and provide URL
     - Example: `https://mywebsite.com/agrology-privacy-policy`
     - Steps: Copy text from `PRIVACY_POLICY_TEMPLATE.md`, host on GitHub Pages or personal site, paste URL
   - **Option B**: Paste privacy policy text directly (some developers do this)

---

## Step 4: Data Safety Form

Location: **Safety > Data Safety**

### Section A: App access & permissions

1. **Does your app collect, use, or share sensitive user or device data?**
   - Select: **YES**

2. **Data type checklist**:
   Mark YES for:
   - [x] **Precise location** (ACCESS_FINE_LOCATION)
   - [x] **Approximate location** (ACCESS_COARSE_LOCATION)
   - [x] **Other data** (Crop selection, growth stage, field boundary, irrigation count)

3. For each data type, you must answer:
   - **Is this data user-generated?** YES (user selects crop, enters irrigations, draws field)
   - **Is this data collected?** YES
   - **Is this data shared?** YES
   - **Is this data encrypted in transit?** YES
   - **Is this data retained?** NO (not on device; backend retention per Render policy)

### Section B: Data sharing

1. **Shared with your own services/backend**:
   - [x] YES
   - Data types: Precise location, approximate location, crop selection, growth stage, field boundary, irrigation count
   - Purpose: Weather analysis, crop recommendations, satellite field analysis

2. **Shared with service providers**:
   - [x] YES (Open-Meteo, Earth Engine)
   - Data types: Location (anonymized)
   - Purpose: Weather data, satellite imagery

3. **Shared with third parties**:
   - Select: NO

### Section C: Security practices

1. **Is data encrypted in transit?** YES (HTTPS)
2. **Is sensitive data encrypted on-device?** NO (data not persisted on device)

### Section D: Data retention

- How long is data kept? **Not stored persistently**
- Users can delete: Clear app data via Settings

---

## Step 5: Target Audience & Content

Location: **Setup > Target audience**

1. **Target audience age**:
   - Select: **NOT an app for children**
   - Select: **Teens and adults**

2. **Consent requirements**:
   - This step handles whether parental consent is needed
   - Since no child data collection: Select **No** (or skip if not applicable)

---

## Step 6: App access & declaration

Location: **Safety > App access & declaration**

Answer the prompts:

1. **Uses Advertising ID?** NO
2. **Requests access to restricted functions**:
   - [x] YES - **Location services (precise)**
     - Justification: "App detects user's province to provide weather and crop recommendations. Permission is requested via system prompt; user can deny and use the app with manual location entry."
   - [x] YES - **Location services (approximate)**
     - Justification: "Fallback coarse location detection if fine location permission not granted."

---

## Step 7: Create Release

Location: **Release > Production**

### Step 7A: Create Release

1. Click **Create new release**
2. You may see: "Google Play App Signing"
   - Choose: **Opt in** (managed by Google)
   - This is recommended for first-time uploads

3. Upload your release bundle:
   - Drag and drop or select: `build/app/outputs/bundle/release/app-release.aab`
   - App will analyze (usually < 1 minute)

### Step 7B: Version & Release Notes

1. **Version code**: Should auto-populate from pubspec.yaml (3 for version 1.0.1+3)
2. **Release notes** (for users):
   ```
   Welcome to Agrology v1.0.1!

   Initial release features:
   - 15+ crops with region-specific guidance
   - Weather-based irrigation scheduling
   - Province auto-detection
   - Livestock & pet care
   - Bilingual support (English & Urdu)
   - Satellite field analysis (NDVI)

   We're committed to helping farmers make smarter decisions.
   Please send feedback to: [YOUR EMAIL]
   ```

3. Click **Save**

---

## Step 8: Review & Rollout

Location: **Release > Production > (Your Release)**

1. **Review the release**:
   - Check all warnings and resolved issues
   - Verify version code is correct (3)
   - Confirm AAB size is ~50–100 MB (typical for Flutter)

2. **Start rollout to production**:
   - Click **Roll out to Production**
   - Confirm you've reviewed all fields
   - Click **Rollout**

### Expected review time:
- **First release**: 2–4 hours typically (can be up to 24 hours)
- **Subsequent updates**: 30 minutes to 2 hours

---

## Step 9: Monitor & Update

Once live on Play Store:

### Check Release Status:
- Go to **Release > Production**
- Status will progress: `In review` → `Approved` → `Live`

### Monitor Crashes:
- Go to **Vitals > ANRs & crashes**
- Review crash logs and fix issues in next update

### Update App Rating:
- Go to **User acquisitions > Ratings & reviews**
- Monitor user feedback

---

## Checklist Before Submission

Before you click "Rollout", verify:

- [ ] App name appears correct: "Agrology"
- [ ] Short description (≤80 chars) is filled in
- [ ] Full description is engaging and informative
- [ ] App icon (512×512) is uploaded
- [ ] At least 2 screenshots (preferably 4) uploaded
- [ ] Feature graphic (1024×500) uploaded
- [ ] Content rating form completed
- [ ] Privacy policy URL provided (must be live/accessible)
- [ ] Data Safety form completed (all sections answered)
- [ ] Target audience set to "Not for children"
- [ ] App access declaration completed (location uses declared)
- [ ] AAB file uploaded (app-release.aab)
- [ ] Version code is 3 (matches 1.0.1+3)
- [ ] Release notes added
- [ ] No warnings or errors shown in review

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| "Privacy policy URL not accessible" | Ensure URL is live and returns HTTP 200. Test in browser. |
| "App crashes on launch" | Check for permission denials or missing backend connectivity. Run local debug build first. |
| "Version code already used" | Increment version in pubspec.yaml (e.g., 1.0.2+4) and rebuild AAB. |
| "Content rating incomplete" | Return to **Setup > Content Rating** and finish questionnaire. |
| "Data Safety form incomplete" | Go to **Safety > Data Safety** and fill all sections. |
| "Screenshot rejected (too small)" | Resize to 1080×1920 minimum; test resolution. |
| "Rejected: Ads detected" | Confirm no AdMob in pubspec.yaml; no ads in code. |
| "Rejected: Location misuse" | Verify location is only used for feature described in Data Safety form. |

---

## Post-Launch Actions

### Immediate (within 1 week of launch)
1. Monitor crash reports in Console
2. Respond to user reviews
3. Monitor rating trends

### Short-term (within 1 month)
1. Prepare v1.0.2 with any bug fixes from user feedback
2. Optimize store listing keywords based on user acquisition data

### Long-term (ongoing)
1. Plan feature updates (livestock sections, more crops)
2. Monitor backend performance (weather API, GIS analysis)
3. Keep privacy policy & data safety info current

---

## Support Resources

- **Flutter Deployment**: https://flutter.dev/deployment/android/
- **Play Console Help**: https://support.google.com/googleplay/android-developer/
- **App Signing**: https://developer.android.com/studio/publish/app-signing
- **Data Privacy & Play Store**: https://support.google.com/googleplay/android-developer/answer/10144311

---

**You're ready to submit! Good luck with Agrology on the Play Store.** 🌾
