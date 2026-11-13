# Vendored in_app_review 2.0.12

This directory is [in_app_review](https://pub.dev/packages/in_app_review) 2.0.12 as published on
pub.dev (MIT licence, see `LICENSE`), copied on 2026-11-14 so that the app can build with AGP's
built-in Kotlin (`android.builtInKotlin=true`, bead aptios-8mo).

## Why

2.0.12 is the latest release and its `android/build.gradle` applies the Kotlin Gradle plugin
(`apply plugin: "kotlin-android"`) and sets `android { kotlinOptions { ... } }`. AGP 9 rejects
both once built-in Kotlin is on, and Flutter warns on every build that a future version will fail
on plugins that apply KGP. Upstream has the fix in review but has not released it:
britannio/in_app_review issue #190, pull requests #188 and #191 (all open on 2026-11-14).

## What differs from upstream

Only `android/build.gradle`:

- `apply plugin: "kotlin-android"` is removed;
- `kotlinOptions { jvmTarget = JavaVersion.VERSION_11 }` inside `android {}` is replaced by a
  top-level `kotlin { compilerOptions { jvmTarget = JvmTarget.JVM_11 } }`, the form built-in
  Kotlin provides.

Left out of the copy because the app does not need them: `example/`, `screenshots/`, `test/` and
the `screenshots:` entry of `pubspec.yaml`. `lib/`, `ios/`, `macos/` and the Kotlin sources are
byte-for-byte the published package.

## When to remove it

As soon as a hosted release supports built-in Kotlin: delete this directory, set
`in_app_review: ^<that version>` in the app's `pubspec.yaml`, run `flutter pub get`, and build a
release app bundle with the pinned Flutter to confirm. Check
https://pub.dev/packages/in_app_review/changelog. Bead aptios-ndt tracks this.
