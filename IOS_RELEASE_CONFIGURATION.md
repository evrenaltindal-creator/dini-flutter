# Dini iOS release configuration

This file is the non-secret source of truth for the iOS release pipeline.

| Setting | Value |
| --- | --- |
| Marketing version | `1.0.0` |
| Main bundle ID | `com.dini.diniFlutter` |
| Widget bundle ID | `com.dini.diniFlutter.widget` |
| App Group | `group.com.dini.dini_flutter` |
| Flutter | `3.47.1` |
| Xcode | `26.6` |

## Secure CI values

The GitHub `testflight` environment, or the corresponding Codemagic variable
groups, must supply these values. Never commit their contents.

- Secret: `APP_STORE_CONNECT_ISSUER_ID`
- Secret: `APP_STORE_CONNECT_KEY_IDENTIFIER`
- Secret: `APP_STORE_CONNECT_PRIVATE_KEY`
- Secret: `CERTIFICATE_PRIVATE_KEY`
- Variable: `APP_STORE_APPLE_ID`
- Variable: `TESTFLIGHT_INTERNAL_GROUP`
- Variable: `DINI_IOS_MONTHLY_PRODUCT_ID`
- Variable: `DINI_IOS_YEARLY_PRODUCT_ID`
- Variable: `DINI_IOS_LIFETIME_PRODUCT_ID`

The app's `.dev` product identifiers remain safe development defaults. The
signed TestFlight workflow refuses to run until all three production StoreKit
identifiers are supplied and none ends in `.dev`.

Monthly and yearly products must be auto-renewable subscriptions in the same
App Store Connect subscription group. Lifetime must be a non-consumable.

## Codemagic variable groups

- `appstore_credentials`: the four secret values above
- `dini_ios_config`: the Apple app ID, internal group name, and three StoreKit
  product identifiers

The widget identifier is a suffix of the main identifier, as required for an
embedded app extension. The signing workflow still fetches both profiles
explicitly. Both targets must use the same Apple team and App Group entitlement.
