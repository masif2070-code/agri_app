# Privacy Policy for Agrology

## Effective Date: April 5, 2026

---

### 1. Introduction

Agrology (the "App") is a mobile application designed to provide agricultural guidance including crop information, pest management, livestock care, irrigation scheduling, and weather-based recommendations for farmers in Pakistan. We are committed to protecting your privacy.

This Privacy Policy explains what information we collect, how we use it, how we protect it, and your rights regarding your data.

---

### 2. Information We Collect

#### 2.1 Location Information

**What we collect:**
- Precise location (latitude and longitude) when you grant permission
- Approximate location (based on network signals)

**When we collect it:**
- Only when you explicitly tap "Use phone location" or use the map picker feature
- You are prompted by your device to grant permission before we collect it

**Why we collect it:**
- To auto-detect your province for province-specific crop recommendations
- To fetch localized weather forecasts
- To enable optional satellite field analysis

**You control it:**
- Location permission is entirely optional
- You can use the app without granting location access (enter location manually)
- You can revoke permission at any time via Settings

#### 2.2 Crop and Field Information

**What we collect:**
- Your selected crop (Wheat, Maize, Rice, etc.)
- Crop category (Field Crops, Vegetables, Fruits)
- Season (Kharif or Rabi)
- Growth stage (for Wheat)
- Number of previous irrigations
- Optional field boundary (polygon) if you draw it on the map

**Why we collect it:**
- To provide crop-specific irrigation recommendations
- To analyze satellite imagery of your field (optional GIS feature)
- To calculate water requirements and disease/pest risk

**Data retention:**
- This data is NOT stored on your device after you close the app
- Each time you open the app, it starts fresh with default settings

#### 2.3 Device and Session Data

**What we do NOT collect:**
- Device identifiers or advertising IDs
- Your phone number or email
- Your name or contact information
- Contacts, calendar, or file access
- Camera or microphone data
- Health or financial information

#### 2.4 Automatic Technical Data

**What we collect:**
- Your app language preference (English or Urdu)
- Your UI state (expanded/collapsed sections, selected options)

**How it's stored:**
- Locally on your device only
- Never sent to our servers

---

### 3. How We Use Your Information

We use the information we collect for these purposes:

1. **Provide App Features** (Primary)
   - Calculate weather-based irrigation schedules
   - Recommend suitable crops based on province and season
   - Provide pest, disease, and livestock management guidance
   - Analyze field images using satellite data (optional)

2. **Improve the App** (Secondary)
   - Understand how the app is used
   - Fix bugs and technical issues
   - Improve features and user experience

3. **Communication** (If applicable)
   - Respond to your support inquiries
   - Notify you of app updates or critical issues

**We do NOT use your data for:**
- Advertising or marketing
- Selling or trading your data
- Automated decision-making or profiling
- Cross-app or cross-device tracking
- Creating detailed user profiles

---

### 4. Who Can Access Your Data

#### 4.1 Our Backend Service

Your location, crop selection, field boundary, and growth stage are sent to our backend server at:
```
https://agri-app-backend-6kyx.onrender.com
```

**Server security:**
- All data is transmitted over HTTPS encryption
- Backend is hosted on Render (managed hosting provider)
- Backend service: Python FastAPI application

**Your data is used by backend for:**
- Weather data fetching
- Crop analysis and recommendations
- Satellite imagery analysis
- User request processing

**Duration & Retention:**
- Backend may retain API logs per Render's hosting policy
- We recommend reviewing Render's privacy policy at https://render.com/privacy

#### 4.2 Third-Party Services

We share data with the following external services **only as necessary for app functionality**:

| Service | Data Shared | Purpose |
|---------|------------|---------|
| Open-Meteo API | Location (lat/lon only) | Weather forecasts |
| OpenStreetMap | None (public map tiles) | Map display |
| Google Earth Engine | Location (via backend proxy) | Satellite field analysis |

**These services:**
- Do not use your data for advertising
- Have their own privacy policies (we recommend reviewing them)
- Only receive data necessary for the specific feature

#### 4.3 Your Choice

- You can **decline any location request** and still use the app
- You can manually enter coordinates instead of requesting location
- You can disable the optional GIS feature entirely

---

### 5. Data Security

#### 5.1 Encryption

- **In Transit**: All data sent to our servers uses HTTPS encryption
- **At Rest**: We do not store location or field data persistently on your device or our servers

#### 5.2 Data Minimization

- We collect only the minimum data needed for the feature you're using
- We do not process data longer than necessary
- API calls are stateless (no user session tracking)

#### 5.3 Access Control

- Backend access is restricted to authorized server processes
- No manual access to user data
- Regular security review via hosting provider

---

### 6. Your Privacy Rights and Choices

#### 6.1 You Have the Right To:

1. **Access**: Know what data we have about you
   - Request: Contact us (see section 10)

2. **Delete**: Remove your data
   - Action: Clear app data via Settings > Apps > Agrology > Storage > Clear Data
   - Effect: All app data is cleared from your device

3. **Opt-Out**: Decline location or other permissions
   - Action: Grant or deny permissions when prompted
   - Effect: App remains functional; you enter data manually

4. **Know**: Understand how your data is used
   - Reference: This privacy policy

#### 6.2 How to Exercise Your Rights

**Option 1: In-App Control**
- Deny location permission via system prompt
- Clear app data via Settings

**Option 2: Contact Us**
- Email: [YOUR CONTACT EMAIL]
- Include: Your request and any relevant details

---

### 7. Data Retention

| Data Type | Retention on Device | Retention on Backend |
|-----------|-------------------|-------------------|
| Location | Session only (cleared when app closes) | Per backend policy* |
| Crop / field data | Session only | Per backend policy* |
| Weather data | Session only | Per backend policy* |
| App settings (language, UI state) | Until user clears app data | N/A (device only) |
| Logs | N/A | Per hosting provider policy* |

*Backend retention policy is determined by Render (hosting provider). See https://render.com/privacy for details.

---

### 8. Updates to This Privacy Policy

We may update this Privacy Policy occasionally to reflect changes in our practices or legal requirements.

- **Notification**: We will update the "Effective Date" at the top of this policy
- **Your Choice**: If we make material changes, we will notify you via app alert or Play Store

**Your continued use of the App after updates constitutes acceptance of the updated policy.**

---

### 9. Children's Privacy

The Agrology app is intended for users 13 and older. If you are under 13, please ask a parent or guardian before using this app.

- We do **not knowingly** collect data from children under 13
- We do **not** use any child-specific data collection techniques
- If we become aware of data from a child under 13, we delete it immediately

---

### 10. Data Breach Notification

In the unlikely event of a data breach:
- We will investigate the incident immediately
- We will notify affected users via Play Store app alert if user credentials are compromised
- We will disclose the nature of the breach within 30 days if required by law

---

### 11. Contact Us

For privacy questions, concerns, or requests:

**Email**: [INSERT YOUR CONTACT EMAIL]  
**Mailing Address**: [INSERT YOUR MAILING ADDRESS IF APPLICABLE]  
**Response Time**: We will respond within 10 business days

---

### 12. Compliance & Legal

#### 12.1 Applicable Laws

This privacy policy complies with:
- Google Play Store Developer Program Policies
- General data protection principles
- Pakistani data protection practices

#### 12.2 Third-Party Links

The app may contain links to external websites (e.g., Wikimedia Commons, weather services). We are not responsible for their privacy practices. Review their policies independently.

---

### 13. Your Consent

By downloading and using the Agrology app, you consent to the collection and processing of your information as described in this privacy policy.

---

### Appendix A: Data Collection Flowchart

```
User Opens App
    ↓
No location collected (app usable without it)
    ↓
User taps "Use Phone Location" or Map Picker
    ↓
System permission prompt appears
    ↓
If Granted → Location sent to backend → Weather fetched → Recommendations shown
If Denied  → User can manually enter coordinates
    ↓
User selects crop → Sent to backend for analysis
    ↓
User views recommendations (all processing on device or backend)
    ↓
User closes app → Session data cleared
```

---

### Appendix B: Hosting Provider & Third-Party Services

| Service | Privacy Policy |
|---------|---|
| Render (Backend Hosting) | https://render.com/privacy |
| Open-Meteo (Weather API) | https://open-meteo.com/privacy |
| OpenStreetMap | https://wiki.openstreetmap.org/wiki/Privacy_Policy |
| Google Earth Engine | https://earthengine.google.com/faq/ |

---

**Last updated: April 5, 2026**  
**Version: 1.0**

---

## How to Use This Policy

1. **Replace placeholders:**
   - `[INSERT YOUR CONTACT EMAIL]` → Your actual email or support contact
   - `[INSERT YOUR MAILING ADDRESS IF APPLICABLE]` → Your business address (if applicable)

2. **Host it:**
   - Option A: Upload to a website (e.g., GitHub Pages, your personal site)
   - Option B: Submit the text directly to Play Console (some developers do this)

3. **Link in Play Console:**
   - Add the full URL to Store Page Settings > Privacy Policy URL
   - Example: `https://yourdomain.com/agrology-privacy-policy`

4. **Keep it updated:**
   - If you add new features that collect data, update the policy
   - Notify users of material changes

---

**End of Privacy Policy Template**
