# Publish Android releases

## Prepare the release

1. Update `version` in [`pubspec.yaml`](../pubspec.yaml). Keep the base version code divisible by 10. For example, `3.0.6+250` produces a Play build with code `250` and FOSS builds with codes `251` for `arm64-v8a`, `252` for `armeabi-v7a`, and `253` for `x86_64`.
2. Add the release changelogs under [`fastlane/metadata/android/`](../fastlane/metadata/android/) in both locales. Use the base code and the three ABI codes, following the existing release. Run `python3 scripts/prepare_fdroid.py --check` with Pillow installed to check the listing.
3. Prepare `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. Relative keystore paths resolve from `android/app/`. For FOSS signing, set `sdk.dir` in `android/local.properties` and install Android SDK Build Tools 35 or newer with `apksigner` and `zipalign`.
4. Build from the clean source commit that the release tag will point to. Run the [project checks](development.md#run-the-checks) before uploading.

## Publish to GitHub and F-Droid

1. Use a dedicated Git checkout of the Flutter SDK on the `stable` branch at the version in `.flutter-version`. From the app repo, run `git -C /path/to/flutter checkout -B stable "$(cat .flutter-version)"`. Use JDK 21 and the NDK in the [live F-Droid recipe](https://gitlab.com/fdroid/fdroiddata/-/blob/master/metadata/com.moaymandev.hadithsearcher.yml).
2. Run `FLUTTER_BIN=/path/to/flutter/bin/flutter ./scripts/release.py foss`. The script signs three APKs in `build/releases/foss/`. Check that their signatures match the recipe's `AllowedAPKSigningKeys`.
3. Publish all three APKs on the GitHub release with a numeric tag such as `3.0.6`, without a `v` prefix. Keep the filenames the script produces, such as `HadithSearcher-3.0.6+251-foss-arm64-v8a.apk`. Stage the APKs on the release before making it public so the reference files are available when F-Droid builds.
4. Check the live recipe for the new version. F-Droid's tag check reads the base version from `pubspec.yaml` and generates three build entries via `VercodeOperation`. F-Droid reproduces each APK against the matching GitHub asset before publishing it with the developer signature. [F-Droid Monitor](https://monitor.f-droid.org/builds) shows build progress. Verify publication in the [package listing](https://f-droid.org/packages/com.moaymandev.hadithsearcher/).

### Update the F-Droid recipe manually

If auto-update fails or the build recipe needs a change, start from the current `fdroiddata` metadata. The [copy in this repository](../fdroid/com.moaymandev.hadithsearcher.yml) is a reference.

- For a new release, add one build per ABI. Pin each `commit` to the source commit used for the signed GitHub APKs. Keep the matching `output` and `binary` per ABI. Set `CurrentVersion` and use the highest ABI code for `CurrentVersionCode`.
- Keep `flutter@stable` and the recipe's `git -C $$flutter$$ checkout -f -B stable "$flutterVersion"` step. It reads the version from `.flutter-version` and resets the reused Flutter checkout to that version on the stable branch. For a Flutter upgrade, update the app's pin and verify the new release against the recipe.
- Run `fdroid rewritemeta com.moaymandev.hadithsearcher` and `fdroid lint com.moaymandev.hadithsearcher` in the `fdroiddata` checkout with the tool versions used by CI. Open the merge request against `fdroid/fdroiddata` and check the pipelines for all three APKs. Verify the production build and listing after merge.

### Verify reproducibility locally

Use the same source commit, Flutter SDK, and Android toolchain as the reference APKs. Run the unsigned builder and compare each rebuilt APK with its signed counterpart. For example:

```sh
python3 scripts/build_foss_unsigned.py --flutter /path/to/flutter/bin/flutter --abi arm64-v8a
python3 -m venv /tmp/hadith-repro-check
/tmp/hadith-repro-check/bin/pip install apksigcopier
/tmp/hadith-repro-check/bin/python scripts/verify_fdroid_reproducibility.py \
  build/releases/foss/HadithSearcher-3.0.6+251-foss-arm64-v8a.apk \
  build/app/outputs/flutter-apk/app-arm64-v8a-foss-release.apk \
  --apksigner "$ANDROID_HOME/build-tools/37.0.0/apksigner"
```

The verifier copies the upstream signature onto the rebuild, validates it, and compares the certificate with the recipe. Repeat for `armeabi-v7a` and `x86_64`. Running the unsigned builder without `--abi` builds all three. Both the release script and the F-Droid recipe use `/var/tmp/hadithsearcher-foss` to keep embedded Dart paths consistent. Run one FOSS build at a time and allow several GiB of disk space. If an interrupted build leaves this directory behind, confirm the build has stopped before removing it.

## Publish to Google Play

Sign in with `shorebird login`, then run `./scripts/release.py play`. The script uses the Flutter version in `.flutter-version`, registers the release with Shorebird, and writes the bundle to `build/releases/play/`. Upload the bundle in Play Console.

Use `./scripts/release.py play --dry-run` to build the bundle without registering a Shorebird release. Run `./scripts/release.py all` to build FOSS and Play in sequence. If Play fails after FOSS succeeds, retry with `./scripts/release.py play`. For a Dart-only Shorebird patch, run `./scripts/release.py patch-play` with the target release version in `pubspec.yaml`.

Switching between Play and FOSS requires the same app signing certificate and a version code at least as high as the installed build. Use the Play app signing key for certificate comparisons. A FOSS APK's code is higher than Play's base code for the same release, so switching back to Play requires a newer release.
