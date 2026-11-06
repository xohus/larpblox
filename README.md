# LarpBlox

LarpBlox is a local roleplay console for profiles, game lists, inventory, and mock trades. [LarpConsole.html](LarpConsole.html) is the shared UI. Each platform packages that file and provides its own entry point.

| Platform | Current state |
| --- | --- |
| iOS | arm64 Settings overlay compiles on GitHub Actions. An IPA assembled from a local Roblox base must be re-signed and tested on device. |
| Android | Integration plan in [android/](android/). |
| Windows | Local console launcher in [windows/](windows/). |
| Browser | Chromium extension starter in [browser/](browser/). |

The iOS workflow builds the overlay and shared console. Base IPAs and signing credentials stay outside the repository.
