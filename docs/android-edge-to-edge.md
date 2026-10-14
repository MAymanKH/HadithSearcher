# Android edge-to-edge

The app targets API 36. Android 15 and later enforce edge-to-edge for this
target. `MainActivity.onCreate` calls `WindowCompat.enableEdgeToEdge(window)`
to support older Android versions too. AndroidX Core 1.17.0 supplies this API.
Flutter startup also selects `SystemUiMode.edgeToEdge` so lifecycle updates
keep the same window layout.

`HadithSearcherApp` protects horizontal content from display cutouts with
`SafeArea`, including routes and dialogs. Its background still fills the window.
`AppBar` handles the status-bar inset. `NavigationBar` pads its destinations
above gesture or button navigation while drawing its background to the bottom
edge. The standalone similar-hadith page protects its body with a bottom safe
area. The consent screen already handles all four insets. Keyboard insets
remain available to `Scaffold`.

System bar styling sets icon brightness and contrast enforcement without
requesting status, navigation, or divider colors. Both app bars and screens
without app bars use the app's selected theme, including when it differs from
the Android theme. Android retains navigation-bar contrast protection for
three-button navigation.

The favourites and search empty states scroll when rotation or the keyboard
leaves too little height for their icons and text.

## Play Console findings

The recommendations attached to release 11 describe its uploaded binary.
Native changes require a new Play AAB; a Shorebird Dart patch cannot update
`MainActivity` or AndroidX dependencies.
The fix uses version `2.1.1+13` because `2.1.0+12` already has a registered
Shorebird release.

The standard Flutter 3.47.2 and Shorebird Flutter 3.47.7 engines used by the
release workflow still include references to `Window.setStatusBarColor`,
`Window.setNavigationBarColor`, and `Window.setNavigationBarDividerColor`.
Their `PlatformPlugin` guards these calls with API checks below 35.
`FlutterActivity` and `FlutterFragmentActivity` also guard their startup
status-bar color calls below API 35. These calls provide compatibility with
older Android releases. The app does not patch Flutter or remove those
compatibility paths with R8 rules.

Google's static analysis can still report these bundled references. A warning
remaining in the Console does not establish an Android 15 layout failure, and
passing local checks does not establish that Google will clear the warning.
The obfuscated `A.e.t` location from release 11 cannot be identified without
that release's R8 mapping.

References:

- [Android edge-to-edge and inset guidance](https://developer.android.com/develop/ui/views/layout/edge-to-edge)
- [WindowCompat.enableEdgeToEdge](https://developer.android.com/reference/androidx/core/view/WindowCompat#enableEdgeToEdge(android.view.Window))
- [Flutter's default edge-to-edge mode](https://docs.flutter.dev/release/breaking-changes/default-systemuimode-edge-to-edge)
- [Flutter's explanation of Play Console warnings](https://github.com/flutter/flutter/issues/169810)

## Verification

The widget regression tests check theme-dependent system icons without color
requests, landscape cutout bounds, bottom navigation destinations, and the
standalone similar-hadith body. The Android integration test exercises the
real window in portrait and landscape, both app themes, all tabs, the consent
screen, the standalone route, and the keyboard. It uses a fake telemetry
backend and sends no telemetry.

```sh
flutter analyze
flutter test test
flutter test integration_test/edge_to_edge_test.dart --flavor fdroid -d emulator-5554
flutter test integration_test/edge_to_edge_test.dart --flavor play -d emulator-5554
./scripts/release.py play --dry-run
```

Run the Android test on API 35 or later and on an older supported Android
version. On API 35 or later, repeat with gesture and three-button navigation
and a simulated display cutout. Check system icon visibility when the app
theme differs from Android's theme. The integration test changes only its
test installation's preferences and restores its orientation request.

If an emulator exposes a hardware keyboard, enable its on-screen keyboard
before testing:

```sh
adb -s emulator-5554 shell settings put secure show_ime_with_hard_keyboard 1
```

Checks on 2026-10-14 passed static analysis and all 19 widget tests. The Android
integration test passed on API 29 with the F-Droid flavor, API 36 with gesture
navigation and the F-Droid flavor, and API 36 with three-button navigation,
a tall simulated cutout, and the Play flavor. Both app themes and orientations
were exercised in each run. API 35 was not tested on a device.
The Shorebird dry-run release build of `2.1.1+13` also passed. Its AAB signature,
package, version, Shorebird configuration, and engine were verified locally.
The bundle was not uploaded to Google Play or registered as a Shorebird release.
