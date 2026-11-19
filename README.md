# Ding

A lightweight SwiftUI client combining Mastodon (any instance, e.g. woof.tech), Bluesky, and Twitter/X into one feed.

## Twitter/X note

X API access is now paid and requires a developer account at console.x.com. Ding supports pasting a bearer/user token if you have one. Without a token, use the "Twitter Web" entry in the More tab, which embeds x.com in-app with no API key.

## Build

Requires Xcode 15+ on macOS. CI builds an unsigned IPA via GitHub Actions.

## Notes

- Deployment target iOS 11.0; SwiftUI views require iOS 13+.
- Accounts stored in UserDefaults; tokens entered by user.
- Optimized for older devices: lazy lists, downscaled image cache, small page sizes.