# Namaz Yolu — two-page reading layout

Implemented 14 November 2026 from the owner's approved preview.

## Behavior

- Compact home keeps its existing mosque scene, greeting, prayer information
  and bottom navigation. The scene stays mounted while tabs and sizes change.
- Expanding a window opens the Qur’an branch at its saved reading position;
  returning to compact width selects Home without clearing branch histories.
  Explicit deep links on launch keep their destination.
- Expanded navigation sits on the physical right in Turkish, English and Arabic.
  Controls use slim labels with usable touch targets.
- Qur’an opens directly, after loading its saved page. Thin verse and juz
  controls navigate using the existing metadata. Two printed Mushaf pages are
  displayed in order from right to left; their text/assets remain unchanged.
- Prayer, ablution and sourced Arabic supplications use a text paginator that
  preserves graphemes and original content. Font size is retained; text flows
  to the next paper. Arabic starts right, Turkish and English start left.
  Existing guided-prayer and individual-part playback remain accessible.
- Expanded calendar shows the daily leaf on the left and month on the right.
  Selecting a day or swiping the leaf updates the other view. Compact calendar
  retains its daily/monthly switch. Both views use the chosen city's date.
- New labels have Turkish, English and Arabic translations. No network service,
  SDK, user data collection, signing, version or distribution change was added.

## Validation

Using Flutter 3.47.1 / Dart 3.13.1:

- `dart format --output=none --set-exit-if-changed .`: passed.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded`: 832 passed, 8 existing tagged
  suites skipped. Includes compact/iPad regressions and twelve new layout,
  transition, right-side Arabic navigation, calendar synchronization and
  text-integrity/accessibility-scale tests.

## Device verification still required

This implementation chooses book mode from available window constraints
(currently at least 700 × 500 logical pixels), not from a hardware hinge angle.
Safe areas are retained and the spread has a 20-point design gutter. That gutter
is not a native iPhone Duo reserved-region integration.

Before an iOS release, use Xcode Device Hub to check outer/inner display sizes,
partial folding and the system's reserved folding/camera regions. Adapt the
gutter to native reserved-region geometry if necessary; Flutter's current
`MediaQuery.displayFeatures` only supplies hardware regions on Android.
No iOS binary, TestFlight upload or App Store submission was produced here.

References:

- [Apple: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
- [Flutter: MediaQueryData.displayFeatures](https://api.flutter.dev/flutter/widgets/MediaQueryData/displayFeatures.html)
