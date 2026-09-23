# DoneNow

DoneNow is a focused iOS timer designed to make a work session feel intentional: choose a timer, choose a visual clock face, add an optional soundscape, and stay in the session.

## Highlights

- Countdown sessions plus a dedicated stopwatch-style mode.
- Themed clock faces with motion tied to timer progress.
- Built-in focus soundscapes and user-imported audio.
- Session completion notifications and background audio behavior.
- Session history and Pro-gated features through StoreKit.
- iPhone and iPad layouts with rotation-aware presentation.

## Engineering focus

DoneNow combines SwiftUI interface work with timer lifecycle management, audio-session handling, local persistence, notifications, StoreKit purchase state, and defensive behavior across foreground/background transitions.

## Build

Open the Xcode project, choose an iOS Simulator or connected device, and run the app. A signed distribution build requires an Apple Developer team and matching App Store Connect configuration.

Build products, signing files, provisioning profiles, and distribution archives are intentionally excluded.

## Testing priorities

1. Start, pause, resume, reset, and complete a timer.
2. Switch clock faces and soundscapes while a session is running.
3. Import and remove a user audio file.
4. Background the app and verify audio and completion notifications.
5. Exercise Pro purchase and restore flows with StoreKit test configuration.
6. Rotate through iPhone and iPad orientations.

DoneNow is a product-engineering example spanning UI, media, persistence, notifications, and in-app purchases.
