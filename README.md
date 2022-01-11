# Aus Phone Towers (iPhone)

Have you ever wondered where your nearest mobile phone tower was? What services does it support?
How fast are the 4G Internet speeds in your area? How far does the signal reach? Which is the best phone provider for you?
Is 5G available in your area?

If so, this app is for you!

Updated weekly with the latest tower information from the Australian Communications and Media Authority (ACMA),
this app presents all you ever wanted to know about your local mobile phone towers in a fun and interactive format.

The app includes details of Telstra, Optus, Vodafone, NBN, TPG, TV, pagers, government, CBRS and aviation transmitters!

The Android version can identify which towers your phone is using, however this feature hasn't been ported to this version of the app yet.

[This repository](https://github.com/bradrushworth/aus_phone_towers_iphone) and its
[Apple App Store listing](https://apps.apple.com/au/app/aus-phone-towers-3g-4g-5g/id1488594332).

[Sister app written in native Java code](https://play.google.com/store/apps/details?id=au.com.bitbot.phonetowers&hl=en_AU&gl=US).
This code is not yet open-sourced but will be soon.

Pull requests are very welcome!

## Getting Started

``
flutter clean
flutter pub get
flutter run
``

I've been testing the app on Windows/Android Studio using the Android version and an Android simulator.

This is primarily a iOS app, so you might require XCode from time to time. I use CodeMagic as my build
pipeline and they allow you to VNC (or SSH) into your build machine for 20 minutes. I've been pretty
much able to avoid using XCode at all, other than to enrol the app with the Apple App Store.
I don't claim to be an expert with Apple, but I think using CodeMagic I can avoid needing access to
XCode mostly, since it only runs on a Mac. There are Mac cloud providers though relatively cheap.

