# Unity iOS Example

## Environment Configuration

The project supports two environments: `staging` and `production`.

| Environment | Scheme | Build configuration | Configuration file | Bundle ID |
| --- | --- | --- | --- | --- |
| Staging | `Unity-iPhone-Staging` | `Debug-Staging` / `Release-Staging` | `Configs/Staging.xcconfig` | `com.kksoft.vn.ts3.staging` |
| Production | `Unity-iPhone` | `Debug-Production` / `Release-Production` | `Configs/Production.xcconfig` | `com.kksoft.vn.ts3` |

### Run staging

1. Open `Unity-iPhone.xcodeproj`.
2. Select the `Unity-iPhone-Staging` scheme.
3. Verify the values in `Configs/Staging.xcconfig`.
4. Build and run the app.

### Run production

1. Open `Unity-iPhone.xcodeproj`.
2. Select the `Unity-iPhone` scheme.
3. Verify the values in `Configs/Production.xcconfig`.
4. Archive or build the app.

`APP_ENV` is passed to `Info.plist` and used to initialize `AuthSDK` with the correct environment:

```text
APP_ENV=staging
APP_ENV=production
```

### Firebase

Each environment uses a separate Firebase configuration file:

| Environment | Firebase plist |
| --- | --- |
| Staging | `firebase/GoogleService-Info-Staging.plist` |
| Production | `firebase/GoogleService-Info-Production.plist` |

When changing the Firebase project, update the plist file and the `FirebaseAppID` value in the corresponding `.xcconfig` file.

## Social Login Configuration

Google Sign-In and Facebook Login are authentication flows handled by `AuthSDK`. They are separate from the tracking providers configured in `TrackingSDK`.

### Google Sign-In

Add the Google iOS OAuth values to each environment `.xcconfig` file:

```text
GIDClientID=<google-ios-client-id>
GIDReversedClientID=<google-reversed-client-id>
```

`GIDClientID` is passed to `Info.plist`. `GIDReversedClientID` is registered in `CFBundleURLSchemes` so Google can redirect back to the app after authentication.

The Google redirect is forwarded to `GIDSignIn.sharedInstance` by `Classes/MyAppController.m`.

### Facebook Login

Add the Facebook platform values to each environment `.xcconfig` file:

```text
FacebookAppID=<facebook-app-id>
FacebookClientToken=<facebook-client-token>
FacebookURLScheme=fb<facebook-app-id>
```

`FacebookAppID` and `FacebookClientToken` are passed to `Info.plist`. `FacebookURLScheme` is registered in `CFBundleURLSchemes`. Facebook lifecycle initialization and redirect handling are implemented in `Classes/MyAppController.m`.

### AuthSDK Server Configuration

During `AuthSDK` initialization, the backend response also provides the Google client ID, Google URL scheme, Facebook client ID, and Facebook client token used by the authentication business flow. `AuthSDK` prefers these backend values and falls back to the matching `Info.plist` values when a backend value is missing.

The iOS `.xcconfig` values and backend values must describe the same environment. The `.xcconfig` values configure the platform SDK redirect behavior, while the backend values are validated and used by `AuthSDK`.

## TrackingSDK Providers

`TrackingSDK` creates and initializes a tracking provider only when its corresponding `enable...()` method is called before `build()`.

| Provider | Enable method | Current app status |
| --- | --- | --- |
| AppsFlyer | `enableAppFlyers(appID:devKey:)` | Disabled |
| Adjust | `enableAdjust(appID:appToken:)` | Enabled |
| TikTok App Events | `enableTikTok(accessToken:appID:tiktokAppID:)` | Enabled |
| Meta App Events | `enableMeta(appID:clientToken:)` | Enabled |
| Firebase Analytics | `enableFirebaseAnalytics(appID:)` | Enabled when the environment Firebase plist exists |
| Firebase Crashlytics | `enableFirebaseCrashlytics()` | Enabled when the environment Firebase plist exists |

If an `enable...()` method is not called, its provider is not created and its SDK is not initialized at runtime. The package dependency is still linked into the app binary.

The current provider setup is in `Classes/AuthWrapper/KKSoftPrxoy.swift`.

## TikTok Configuration

TikTok App Events is initialized through `TrackingSDK` in `Classes/AuthWrapper/KKSoftPrxoy.swift`.

Add the TikTok credentials to the `.xcconfig` file for each environment:

```text
TiktokAppID=<tiktok-app-id>
TiktokAccessToken=<tiktok-events-manager-access-token>
```

Example:

```text
# Configs/Staging.xcconfig
TiktokAppID=<staging-tiktok-app-id>
TiktokAccessToken=<staging-access-token>

# Configs/Production.xcconfig
TiktokAppID=<production-tiktok-app-id>
TiktokAccessToken=<production-access-token>
```

These values are passed to `Info.plist`, then provided to:

```swift
.enableTikTok(
    accessToken: Bundle.main.infoDictionary?["TiktokAccessToken"] as? String ?? "",
    appID: Bundle.main.bundleIdentifier ?? "com.kksoft.vn.ts3.staging",
    tiktokAppID: Bundle.main.infoDictionary?["TiktokAppID"] as? String ?? ""
)
```

`appID` is the iOS bundle ID for the selected environment. `TiktokAppID` is the TikTok application ID. `TiktokAccessToken` is the access token created in TikTok Events Manager.

Do not commit the production access token if the repository can be accessed outside the team. For CI builds, inject the token into the `.xcconfig` file during the build process.

## Meta App Events Configuration

Meta App Events uses the Facebook credentials from each environment configuration:

```text
FacebookAppID=<meta-app-id>
FacebookClientToken=<meta-client-token>
```

`TrackingSDK` enables Meta tracking through `enableMeta(appID:clientToken:)`. The active environment values are passed from the corresponding `.xcconfig` file through `Info.plist`.

Meta App Events supports custom events, purchases, user properties, and user IDs. The Facebook SDK lifecycle is initialized by `Classes/MyAppController.m`.

Meta App Events and Facebook Login are separate flows, but they reuse the same `FacebookAppID` and `FacebookClientToken` because both features use the Facebook SDK global configuration.

## Pre-release Checklist

1. Select the correct scheme.
2. Verify `APP_ENV`, `APP_BUNDLE_ID`, and `APP_DISPLAY_NAME`.
3. Verify `GIDClientID` and `GIDReversedClientID`.
4. Verify `FacebookAppID`, `FacebookClientToken`, and `FacebookURLScheme`.
5. Verify the Firebase plist and `FirebaseAppID` for the selected environment.
6. Verify `TiktokAppID` and `TiktokAccessToken`.
7. Build the app and check for the `KKSOFT Proxy TrackingSDK Initialized` log message.
