# UneBil Delivery Rules

Read this file before making or reporting any change in this repository.

## A change is not delivered until the user can see it

For every Android UI or behavior change:

1. Inspect the current source and preserve unrelated user changes.
2. Implement and format the change.
3. Run static analysis and relevant tests.
4. Build a fresh Android APK from the current source.
5. Verify that the APK timestamp is newer than the source changes.
6. If an Android device is connected, install the fresh APK with ADB and open
   the updated screen.
7. Visually verify the actual installed application at the requested narrow
   phone width. Tests alone are not sufficient for UI delivery.
8. When possible, capture a screenshot from the installed application and
   compare it with the requested result.

Never say that an Android UI task is finished when only source code or widget
tests were checked. Clearly distinguish these states:

- implemented in source;
- APK built;
- APK installed on the user's device;
- visually verified on the user's device.

If no device is connected, say that installation and visual verification are
still pending. Do not imply that the user is already running the new version.

Before handing off an APK, copy the newly built artifact to the agreed
user-facing filename and report its exact path, size, and modification time.
Do not assume that an older APK in the repository contains the latest changes.

## Required final checks

- `git diff --check`
- static analysis
- Flutter tests
- fresh APK build
- `adb devices -l`
- installed package version or APK timestamp
- visual check of the changed screen when a device is available
