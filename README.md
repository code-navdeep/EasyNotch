# EasyNotch

A lightweight macOS app that turns your MacBook's notch into a music control center —
album art, track info, a scrubber, and playback controls right at the top of your screen.

## Features

- Live music activity in the notch with album art and a music visualizer:
  an audio-reactive spectrum (macOS 14.4+, asks for system-audio permission)
  or a decorative animated equalizer
- Full playback controls: play/pause, next/previous, shuffle, repeat, volume, favorite
- Works with Apple Music, Spotify, YouTube Music, and any app via the system Now Playing source
- Hover or gesture to expand the notch; customizable control layout
- Lyrics (via lrclib.net or Apple Music), including a synced-lyrics panel in the open notch
- Scroll on the closed notch to change volume (vertical) or seek (horizontal)
- Optional horizontal swipes to change tracks
- Built-in update mechanism via Sparkle — **not active yet**, see [Updates](#updates)

YouTube Music support requires the third-party
[youtube-music](https://github.com/th-ch/youtube-music) desktop app with its
API server plugin enabled.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel Mac

## Updates

EasyNotch bundles the Sparkle update framework, but **automatic updates are not
live yet.** `Info.plist` ships with a placeholder feed URL
(`https://REPLACE-ME.example.com/appcast.xml`) and no `SUPublicEDKey`, so
"Check for Updates…" will not find anything.

This is deliberate rather than broken: Sparkle treats a *missing* public key as
acceptable while a *placeholder* one is fatal at launch, and Apple code signing
already covers the integrity of the build you downloaded. A real update feed is
planned for a future version.

Until then, new versions are published on the [Releases page](../../releases)
and are installed by downloading the new disk image.

If you are building and distributing your own fork,
[docs/RELEASING.md](docs/RELEASING.md) documents the full Sparkle setup —
generating a key pair, hosting `appcast.xml`, and signing each update.

## Building

1. Open `EasyNotch.xcodeproj` in Xcode.
2. **Set your own signing team** under Signing & Capabilities. This project ships
   with an empty `DEVELOPMENT_TEAM`, so you must select yours before the app will
   sign.
3. Build and run.

### The bundled MediaRemoteAdapter framework

`mediaremote-adapter/MediaRemoteAdapter.framework` is vendored into this
repository rather than fetched by a package manager, because Xcode embeds it
directly from the project folder. It is **not optional** — the build fails
without it. (The Swift Package Manager dependencies, by contrast, are downloaded
automatically and are not committed here.)

The framework is embedded with **Code Sign On Copy**, so Xcode re-signs it with
whatever team is building the app. Before the app hands the framework's path to
an unentitled `/usr/bin/perl` subprocess — which is not covered by the app's own
hardened runtime — `MediaRemoteAdapterValidator` checks that the framework is
signed by the same Team ID that signed the running app.

That Team ID is read from the app's own code signature at runtime, so **no code
change is needed when you build with your own team.** Set your signing team in
step 2 and the check follows it.

Unsigned and ad-hoc-signed builds have no Team ID, so the check cannot pass and
the Now Playing integration will be unavailable. Sign with a real team to use it.

## License

EasyNotch is released under the MIT License. See [LICENSE](LICENSE).

One exception: `EasyNotch/private/CGSSpace.swift` is licensed under the Mozilla
Public License 2.0, which applies per file. That file remains under MPL-2.0
regardless of the license covering the rest of this project.

All third-party components and their licenses are listed in
[THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).
