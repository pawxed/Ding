# Ding

A lightweight SwiftUI client combining Mastodon (any instance, e.g. woof.tech), Bluesky, and Twitter/X into one feed.

## Twitter/X setup (console.x.com)

1. Create an app at console.x.com.
2. Set App type to "Native App" (public client, no secret needed).
3. Under User authentication settings, add Callback URL `ding://oauth-callback` and any Website URL.
4. In Keys and Tokens, copy the OAuth 2.0 Client ID.
5. Paste the Client ID in Ding's Accounts tab and tap "Sign in with Twitter".

If no Client ID is shown, contact X developer support.

## Build

Requires Xcode 15+ on macOS. CI builds an unsigned IPA via GitHub Actions.

## Notes

- Deployment target iOS 11.0; SwiftUI views require iOS 13+.
- Accounts stored in UserDefaults; tokens entered by user.
- Optimized for older devices: lazy lists, downscaled image cache, small page sizes.