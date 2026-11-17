# Security, Privacy & Code-Signing Policy

- Developer: Jorgen Thompquist
- Apple Developer Team ID: D3BJL3F92P
- Bundle Identifier: com.krouton.opticalstudio

## Signature & Notarization Verification

    codesign -dv --verbose=4 /Applications/Krouton.app
    spctl -a -t exec -vv /Applications/Krouton.app

## Privacy Manifest (PrivacyInfo.xcprivacy)
- NSPrivacyTracking: false (zero analytics or third-party telemetry).
- Declared Required Reason APIs: CA92.1 (UserDefaults), C617.1 (File Timestamps), E174.1 (Disk Space).
