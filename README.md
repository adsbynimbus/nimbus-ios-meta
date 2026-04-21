# NimbusMetaKit

A Nimbus SDK extension for **Meta bidding and rendering**. It enriches Nimbus ad requests with Meta demand and handles ad rendering through the FBAudienceNetwork SDK when it wins the auction.

## Versioning
 
NimbusMetaKit **major versions are kept in sync** with the FBAudienceNetwork SDK. For example, NimbusMetaKit `6.x.x` depends on FBAudienceNetwork SDK `6.x.x`.
 
Minor and patch versions are independent — a NimbusMetaKit patch release does not necessarily correspond to an FBAudienceNetwork SDK patch release, and vice versa.
 
| NimbusMetaKit | FBAudienceNetwork SDK |
|---|---|
| 6.x.x | 6.x.x |

## Installation

### Swift Package Manager

#### Xcode Project

1. In Xcode, go to **File → Add Package Dependencies…**
2. Enter the repository URL:
   ```
   https://github.com/adsbynimbus/nimbus-ios-meta
   ```
3. Set the dependency rule to **Up to Next Major Version** and enter `6.0.0` as the minimum.
4. Click **Add Package** and select the **NimbusMetaKit** library when prompted.

#### Package.swift

If you're managing dependencies through a `Package.swift` file, add the following:

```swift
dependencies: [
    .package(url: "https://github.com/adsbynimbus/nimbus-ios-meta", from: "6.0.0")
]
```

Then add the product to your target:

```swift
.product(name: "NimbusMetaKit", package: "nimbus-ios-meta")
```

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'NimbusMetaKit'
```

Then run:

```sh
pod install
```

## Usage
 
Navigate to where you call `Nimbus.initialize` and register the `MetaExtension`:
 
```swift
import NimbusMetaKit
 
Nimbus.initialize(publisher: "<publisher>", apiKey: "<apiKey>") {
    MetaExtension(appId: "<metaAppId>") // pass forceTestAd: true for testing
}
```

If you provide an app ID, Nimbus will automatically initialize the FBAudienceNetwork SDK.

That's it — Meta is now enabled in all upcoming requests.

## Documentation

- [Nimbus iOS SDK Documentation](https://docs.adsbynimbus.com/docs/sdk/ios) — integration guides, configuration, and API reference.
- [DocC API Reference](https://iosdocs.adsbynimbus.com) — auto-generated documentation for the latest release.

## Sample App

See NimbusMetaKit in action in our public [sample app repository](https://github.com/adsbynimbus/nimbus-ios-sample), which demonstrates end-to-end integration including setup, bid requests, and ad rendering.
