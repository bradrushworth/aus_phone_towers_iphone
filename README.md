# Aus Phone Towers (iPhone)

Have you ever wondered where your nearest mobile phone tower was? What services does it support?
How fast are the 4G Internet speeds in your area? How far does the signal reach? Which is the best phone provider for you?
Is 5G available in your area?

If so, this app is for you!

Updated weekly with the latest tower information from the Australian Communications and Media Authority (ACMA),
this app presents all you ever wanted to know about your local mobile phone towers in a fun and interactive format.

The app includes details of Telstra, Optus, Vodafone, NBN, TPG, TV, pagers, government, CBRS and aviation transmitters!

## Connected tower feature

The Android version can identify which towers your phone is using. This is not available on iOS
because Apple's public APIs do not expose the required cell-tower data.

On Android, `TelephonyManager.getAllCellInfo()` can read the serving and neighbouring cells,
including cell ID, LAC/TAC, MCC/MNC, signal strength, ARFCN and timing advance. The app then looks
those cells up against ACMA / OpenCellID data and shows the connected tower on the map.

On iOS, `CoreTelephony` / `CTTelephonyNetworkInfo` only exposes the carrier name, MCC/MNC,
country code and current radio access technology (e.g. 4G or 5G). It does **not** provide the
connected cell tower ID, signal strength, ARFCN, timing advance or neighbour cell data. Richer
cell data would require private APIs or restricted entitlements that Apple does not allow in
App Store apps.

For that reason, the iOS app shows nearby towers based on your GPS location, but it cannot
currently display the specific tower your phone is connected to.

Some relevant links:

* [This repository](https://github.com/bradrushworth/aus_phone_towers_iphone)
* [Apple App Store listing](https://apps.apple.com/au/app/aus-phone-towers-3g-4g-5g/id1488594332)
* [Sister app written in native Java code](https://play.google.com/store/apps/details?id=au.com.bitbot.phonetowers&hl=en_AU&gl=US)
  This code is not yet open-sourced but will be soon.

Pull requests are very welcome!

## Getting Started

Here are some random commands:

```
flutter clean
flutter pub get
flutter run
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/better_test.dart
```

I've been testing the app on Windows/Android Studio using the Android version and an Android
simulator.

This is primarily a iOS app, so you might require XCode from time to time. I use CodeMagic as my build
pipeline and they allow you to VNC (or SSH) into your build machine for 20 minutes. I've been pretty
much able to avoid using XCode at all, other than to enrol the app with the Apple App Store.
I don't claim to be an expert with Apple, but I think using CodeMagic I can avoid needing access to
XCode mostly, since it only runs on a Mac. There are Mac cloud providers though relatively cheap.

## Web Version

If you encounter issues with Chrome complaining about CORS while you are testing, the following
solution fixed my issue. This should no longer be relevant because I allow http://localhost in my
CORS configuration now.

[How to solve flutter web api cors error only with dart code?](https://stackoverflow.com/questions/65630743/how-to-solve-flutter-web-api-cors-error-only-with-dart-code)

[flutter_cors](https://pub.dev/packages/flutter_cors)

```
dart pub global activate flutter_cors
fluttercors disable
fluttercors enable
```
