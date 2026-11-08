# Paws and Ponder – Android

A Pomodoro timer for Android. The app opens straight into a full-screen timer. Settings and History open as overlays on top of it.

- Package: `com.example.pawsandponder`
- Version: 1.0
- Min SDK 34 (Android 14), target/compile SDK 37
- Built with Kotlin and Jetpack Compose (Material 3)

## Features

### Timer
- Work and break phases with adjustable lengths (defaults: 25 and 5 minutes; work 1–180, break 1–60).
- Start, pause, reset and skip to the next phase.
- Optional auto-start of the break after work (on by default) and of work after a break (off by default).
- Changing a length mid-phase applies immediately and keeps the time already elapsed.
- Runs from an end timestamp instead of counting ticks, so it stays accurate through Doze and delayed callbacks.
- Sound and notification when a phase ends, each with its own toggle. The notification names the next phase and its length.

### Display
- **Digital:** a large mm:ss countdown.
- **Analog:** a circular clock face with a ring that fills as the phase elapses and a sweeping hand.
- Switch between the two in Settings.
- Light, dark or system theme.
- Immersive full-screen mode, and the screen stays on while the timer runs.

### Lock screen
- Ongoing notification with a live countdown and Pause and Skip actions, running as a foreground service so Android doesn't kill the timer.
- "Show on lock screen" toggle, plus a "hide content" option that shows only "Paws and Ponder".
- The full-screen timer can show over the lock screen during a session, and the screen turns on when a phase ends.

### Do Not Disturb
- Phase-end sound and notification can break through Do Not Disturb (alarm-category channel).
- Status line in Settings shows whether the Do Not Disturb access permission is granted, with a shortcut to the system settings page.
- Optional: turn Do Not Disturb on automatically during work and off during breaks, restoring your previous setting afterwards.

### Work history (optional, off by default)
- Records work time per day for the last 4 months, and nothing while the setting is off.
- GitHub-style activity grid shaded by hours worked. Tap a day to see its time.
- Work time is split at midnight, and a running session is saved when the app closes.

## Permissions

| Permission | Why |
| --- | --- |
| `POST_NOTIFICATIONS` | Phase-end and ongoing timer notifications |
| `USE_EXACT_ALARM` | Fire the phase-end alert on time |
| `ACCESS_NOTIFICATION_POLICY` | Override or control Do Not Disturb (granted by the user in system settings) |

## Building the APK

### Prerequisites

- **JDK 17 or newer.** If `java` isn't installed, `build-apk.sh` falls back to the JDK bundled with Android Studio.
- **Android SDK** with platform 37 and recent build-tools. Point to it with either:
  - `ANDROID_HOME` (or `ANDROID_SDK_ROOT`), or
  - a `local.properties` file in this folder containing `sdk.dir=/path/to/Android/sdk`
  (Android Studio creates `local.properties` for you when you open the project.)
- No separate Gradle install is needed; the included `./gradlew` wrapper downloads Gradle 9.6.0.

### Debug APK (quickest, installable as-is)

```sh
cd android/pawsAndPonder
./build-apk.sh
```

Output: `dist/PawsAndPonder-1.0-debug.apk`. It is signed with the debug key and ready to install.

### Release APK

```sh
./build-apk.sh release
```

Without signing details, this produces `dist/PawsAndPonder-1.0-release-unsigned.apk`, which **can't be installed** until it is signed.

To get a signed release APK, set these environment variables first:

```sh
export KEYSTORE_PATH=/path/to/my-release.jks
export KEYSTORE_PASSWORD=...
export KEY_ALIAS=...
export KEY_PASSWORD=...   # optional, defaults to KEYSTORE_PASSWORD
./build-apk.sh release
```

Output: `dist/PawsAndPonder-1.0-release.apk`, signed with `apksigner` and verified.

Don't have a keystore? Create one:

```sh
keytool -genkeypair -v -keystore my-release.jks -alias paws \
  -keyalg RSA -keysize 2048 -validity 10000
```

Keep the keystore and its passwords private; `*.jks`, `*.keystore` and `keystore.properties` are git-ignored.

### Building without the script

```sh
./gradlew :app:assembleDebug     # app/build/outputs/apk/debug/app-debug.apk
./gradlew :app:assembleRelease   # app/build/outputs/apk/release/app-release-unsigned.apk
```

You can also use Android Studio: open this folder, then **Build → Build APK(s)** (or **Generate Signed Bundle / APK** for release).

## Installing

With a device connected over USB (USB debugging on) or a running emulator:

```sh
adb install -r dist/PawsAndPonder-1.0-debug.apk
```

Or copy the APK to the phone and open it, allowing "install unknown apps" for your file manager when prompted.

On first launch, grant the notification permission. To use the Do Not Disturb features, enable **Do Not Disturb access** for the app from the in-app prompt in Settings.

## Tests

```sh
./gradlew :app:testDebugUnitTest
```
