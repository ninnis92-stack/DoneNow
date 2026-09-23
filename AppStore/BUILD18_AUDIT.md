# Build 18 verification — 2026-09-21

Changes: adaptive iPad portrait/landscape layout; narrow-window clock fit; banner requests after window attachment; changing built-in or imported music preserves active playback. Paused selections remain paused. Build number 18.

Validation:
- Signed Release archive succeeded (DoneNow-build18-final.xcarchive).
- 17 XCTest cases passed on the 13-inch iPad simulator, including all 11 soundscapes switched during playback, mute/volume/pause retention, banner attachment/reattachment, layout boundaries, repeated resizing, and portrait/landscape rendered captures.
- Final soundscape switching test also passed on the iPhone simulator.
- Static adversarial audit passed after the final audio change.
- Portrait iPad and iPhone screenshots inspected; test banners loaded on both. Landscape rendering inspected from the hosting test.

Limits: window resizing tests are not a physical-device rotation test. No physical iPad was available. Device audio routes, lock-screen behavior, purchases, and live ad inventory were not end-to-end retested in this pass. Existing timer/purchase/persistence logic was not changed. iPhone layout policy retains the 285-point clock except in windows too narrow to fit it. TestFlight upload status must be checked separately.

Upload: Xcode reported “Upload succeeded”, “Uploaded DoneNow”, and “EXPORT SUCCEEDED” at 08:32 on September 21. Non-blocking missing dSYM warnings apply to GoogleMobileAds and UserMessagingPlatform. Internal group distribution is set to Automatic for Xcode Builds. Processing/availability still requires App Store Connect confirmation.
