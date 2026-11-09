# Medicine Reminder — Mobile Application

**Student Name & Surname:** Abdullah Cari  
**Student Number:** B2180.060049  
**Course:** Mobile Application Development / Mobile Programming  
**Term Project:** Clinical Dosage, Circadian Timing, Multi-Profile Caregiver & Adherence Tracking System  

---
# Medicine Reminder — Mobile Application Term Project

**Course:** Mobile Application Programming (Mobile Computing)  
**Student:** Abdullah  
**Platform:** Flutter / Dart / Cross-Platform Mobile  
**Deliverable Version:** Final Term Submission (v1.0.0)  

---

## 📦 Package Contents

1. **`lib/`**: Complete Flutter source code
   - `main.dart`: App bootstrap, Material 3 theming, notification setup
   - `models/pill_model.dart`: Structured pharmaceutical domain model
   - `services/db_helper.dart`: Double-table SQLite database operations & history logging
   - `services/notification_service.dart`: Timezone-aware local notification manager
   - `screens/home_screen.dart`: Main dashboard, 3-tab views, profile switcher, language toggle
   - `screens/add_pill_screen.dart`: Dosage form selector, interval stepper, clinical warnings
2. **`preview/index.html`**: Zero-dependency interactive web preview with Web Audio API chime
3. **`screenshots/`**: High-resolution screenshots of all operational screens & live iPhone testing
4. **`PROJECT_REPORT.md`**: Comprehensive academic term project report (in English)
5. **`PROJECT_REPORT.html`**: Print-ready and browser-viewable formatted report (Save as PDF)
6. **`pubspec.yaml`**: Flutter package specification & dependency manifest

---

## 🚀 How to Run

### Option 1: Mobile Device / Web Preview (Immediate Live Test)
Open `preview/index.html` in any modern desktop or mobile browser (Chrome, Safari, Edge):
- **Live Network Testing:** Host with any local HTTP server (`python -m http.server 8080 --directory preview`) and access via iPhone/Android browser over Wi-Fi.

### Option 2: Flutter Mobile Application
Ensure Flutter SDK (v3.0+) is installed, then run:
```bash
flutter pub get
flutter run
```
Supports Android, iOS, macOS, Windows, and Web.

---

## 🌟 Key Engineering Features

- **User-Defined Dynamic Interval Stepper:** Schedule medicines to be taken every 1, 2, 3, 4... X days.
- **Medication History Log ("What Did I Take Yesterday?"):** Permanent audit trail of every taken dose with exact timestamps.
- **Circadian Sirkadiyen Timing:** Synchronized with medical practice (Morning: 08:30, Noon: 13:00, Evening: 19:30, Night: 22:30).
- **Clinical Safety Warnings:** Automated alerts for decongestant 5-day limits, throat spray NPO rules, asthma puff rinsing, and drop sterility.
- **Multi-Profile Caregiver Mode:** Manage treatments for Myself, Child, and Elderly Parent from a single device.
- **Automatic Inventory Depletion & Refill Alert:** Decrements stock on intake and triggers alarms when inventory drops to 3 units.
- **100% Bilingual Architecture:** Full runtime toggle between English (🇬🇧) and Turkish (🇹🇷) with zero residual strings.
