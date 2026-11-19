# Ding

A lightweight SwiftUI client combining Mastodon (any instance, e.g. woof.tech), Bluesky, and Twitter/X into one feed.

## Build

Requires Xcode 15+ on macOS. CI builds an unsigned IPA via GitHub Actions.

## Notes

- Deployment target iOS 11.0; SwiftUI views require iOS 13+ and are hosted via UIHostingController.
- Accounts are stored in UserDefaults; tokens are entered by the user.
- Optimized for older devices: lazy lists, downscaled image cache, small page sizes.