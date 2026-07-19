# Android port target

Approved on 2026-07-19.

## Target devices

- Platform: Android phones first; tablets and foldable devices are a secondary target.
- Minimum OS: Android 7.0 (API 24).
- CPU architecture: ARM64 (`arm64-v8a`).
- Orientation: landscape, locked while the game is running.
- Phone aspect ratios: 16:9 through 21:9.
- Tablet layouts: supported after the primary phone layout is stable.

## Runtime targets

- Preferred frame rate: 60 FPS.
- Acceptable fallback mode: 30 FPS for low-end devices.
- Gameplay coordinate space: 1280 x 720, centered inside the available display area.
- Renderer target: Compatibility, subject to visual-regression testing against the current Forward+ output.

## Distribution

- Android application ID: `com.kirillrnd.ellipse`.
- Debug and QA builds: APK.
- Google Play release: signed AAB.
- Primary release architecture: ARM64 only.
- Google Play target API: API 36 for releases submitted on or after 2026-08-31.
