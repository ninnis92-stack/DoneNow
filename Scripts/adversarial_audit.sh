#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { print -u2 "AUDIT FAILED: $1"; exit 1; }

[[ -f Config/Info.plist ]] || fail "Info.plist is missing"
[[ -f Sources/AudioPlayer.swift ]] || fail "AudioPlayer.swift is missing"
[[ -f Sources/ProStore.swift ]] || fail "ProStore.swift is missing"

# The offline library must remain available without a network connection.
soundscape_count=$(rg -c '^[[:space:]]+case (atmosphere|thunderstorm|rain|ocean|fireplace|forest|stream|softWind|morningBirds|deepSpace|rainDelay)[[:space:]]*$' Sources/AudioPlayer.swift | awk -F: '{sum += $NF} END {print sum + 0}')
[[ "$soundscape_count" -eq 11 ]] || fail "Expected 11 built-in soundscapes, found $soundscape_count"

title_count=$(rg -o 'return "(Timekeeper|Thunderstorm|Gentle Rain|Calm Ocean|Fireplace|Forest|Quiet Stream|Soft Wind|Morning Birds|Deep Space|Rainfall Reverie)"' Sources/AudioPlayer.swift | wc -l | tr -d ' ')
[[ "$title_count" -eq 11 ]] || fail "Every soundscape must have a user-facing title"

grep -q '<string>audio</string>' Config/Info.plist || fail "Background audio mode is missing"
rg -q 'numberOfLoops = -1' Sources/AudioPlayer.swift || fail "Built-in audio is not configured to loop"
rg -q 'makeBuiltInSoundscape' Sources/AudioPlayer.swift || fail "Built-in fallback generator is missing"
! rg -q 'soundFileName|url\(forResource:.*vibe' Sources/AudioPlayer.swift || fail "Built-in soundscapes must not share a generic track"
rg -q 'let saved = UserDefaults.standard.string\(forKey: soundscapeKey\)' Sources/AudioPlayer.swift || fail "Saved soundscape selection is not restored"
rg -q 'size <= 250 \* 1024 \* 1024' Sources/AudioPlayer.swift || fail "Imported audio size guard is missing"
rg -q 'useImportedFocusAudio' Sources/AudioPlayer.swift || fail "Imported audio selection persistence is missing"
rg -q 'set\(false, forKey: useImportedAudioKey\)' Sources/AudioPlayer.swift || fail "Built-in selection does not clear imported-audio selection"
rg -q 'try\? AVAudioSession\.sharedInstance\(\)\.setActive\(false' Sources/AudioPlayer.swift || fail "Audio session deactivation is missing"

# Notification failures must be visible and recoverable rather than silently
# dropping completion or daily reminder alerts.
rg -q 'Notifications are off' Sources/CompletionNotificationScheduler.swift || fail "Completion notification denial feedback is missing"
rg -q 'Open Notification Settings|UIApplication\.openSettingsURLString' Sources/SettingsView.swift Sources/MainFocusView.swift || fail "Notification settings recovery path is missing"
rg -q 'The daily reminder could not be scheduled' Sources/FocusScheduleStore.swift || fail "Daily reminder scheduling failure feedback is missing"

# A running session must not be silently reset by changing its duration.
rg -q '\.disabled\(timer\.isRunning\)' Sources/MainFocusView.swift || fail "Running timer duration guard is missing"

# Ad consent failures need a retry path so a transient network/consent error
# does not permanently suppress ads for the process lifetime.
rg -q 'func retry\(\)' Sources/AdMobCoordinator.swift || fail "Ad consent retry path is missing"
rg -q 'Retry ad setup' Sources/AdBannerSlot.swift || fail "Ad consent retry UI is missing"

# Purchase-flow checks: only the canonical App Store product ID may resolve
# through StoreKit or grant a verified Pro entitlement.
rg -q 'static let productIDs' Sources/ProStore.swift || fail "StoreKit product ID list is missing"
rg -q 'com\.naheeminnis\.donenow\.pro' Sources/ProStore.swift || fail "Current Pro product ID is missing"
! rg -q 'local\.aelo\.donenow\.pro' Sources/ProStore.swift || fail "Legacy Pro product ID must not grant access"
rg -q 'Product\.products\(for: Self\.productIDs\)' Sources/ProStore.swift || fail "StoreKit does not request the configured product IDs"
rg -q 'Self\.productIDs\.contains\(transaction\.productID\)' Sources/ProStore.swift || fail "Entitlement verification does not handle configured product IDs"
rg -q 'ensureProductLoaded\(\)' Sources/ProStore.swift || fail "Purchase can race the initial StoreKit product lookup"
rg -q 'Purchase completed; Pro access is still syncing' Sources/ProStore.swift || fail "Purchase entitlement sync status is missing"

# Stopwatch must be additive: it counts upward, does not trigger countdown
# completion, and exposes an explicit save path for history records.
rg -q 'case stopwatch' Sources/TimerEngine.swift || fail "Stopwatch mode is missing"
rg -q 'mode == \.stopwatch' Sources/TimerEngine.swift || fail "Stopwatch timing path is missing"
rg -q 'Finish and Save Session' Sources/MainFocusView.swift || fail "Stopwatch save control is missing"
rg -q 'history\.record\(duration: timer\.elapsedTime' Sources/MainFocusView.swift || fail "Stopwatch sessions are not recorded"
rg -q 'timer\.mode == \.countdown' Sources/MainFocusView.swift || fail "Countdown-only completion guard is missing"

# Guard against shipping the debug entitlement override in release code paths.
rg -q '#if DEBUG' Sources/MainFocusView.swift || fail "Pro debug override is not compile-time gated"

if rg -n 'fatalError\(|preconditionFailure\(|try!|as!' Sources Config; then
  fail "Unsafe failure or force-cast found in production sources"
fi

printf "Adversarial static audit passed: soundscapes=%s, titles=%s\n" "$soundscape_count" "$title_count"
