<p align="center">
  <img src="assets/icono/SentriCam.png" alt="SentriCam" width="140">
</p>

<h1 align="center">SentriCam</h1>

<p align="center">
  <a href="https://github.com/4lanPz/SentriCam/releases/latest"><img src="https://img.shields.io/github/v/release/4lanPz/SentriCam?label=version" alt="Version"></a>
  <a href="https://github.com/4lanPz/SentriCam/releases"><img src="https://img.shields.io/github/downloads/4lanPz/SentriCam/total?label=downloads" alt="Downloads"></a>
  <a href="https://github.com/4lanPz/SentriCam/stargazers"><img src="https://img.shields.io/github/stars/4lanPz/SentriCam?label=stars" alt="Stars"></a>
  <img src="https://img.shields.io/badge/Android-7.0%2B-3DDC84?logo=android&logoColor=white" alt="Android 7.0+">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/4lanPz/SentriCam?label=license" alt="MIT License"></a>
</p>

<p align="center">
  <a href="README.md">Español</a> · <b>English</b>
</p>

<p align="center">
  Camera viewer for Hikvision DVRs and NVRs on Android TV.<br>
  Show only the cameras you care about, from one or several recorders, in a paged grid on your TV.
</p>

---

> **Note:** the app's interface is in Spanish.

## What is it?

SentriCam is an Android TV app (it also works on Android tablets and phones) that shows live video from your Hikvision DVRs/NVRs over RTSP.

It is designed for closed, local installations with many cameras where the TV only needs to show some of them: you choose which cameras to watch, they are split into pages, and the TV only plays the cameras on the visible page, so it runs well even on modest hardware.

Everything works **inside your local network**: the app uses no external servers, no cloud accounts and no internet.

## Features

- **Several DVRs at once**: add as many DVRs/NVRs as you need.
- **Automatic names**: the app asks each DVR which channels it has and uses the camera names already set on the DVR. No need to type them.
- **Paged grid**: 1, 4, 6, 9 or 16 cameras per page.
- **Automatic page switching** (optional) at a set interval, with a button to pause it.
- **Groups**: combine cameras from different DVRs into one view (for example, all cameras on one floor) and choose on the TV what to watch: everything, a group or a single DVR.
- **Full screen** in main-stream quality when you select a camera.
- **Browser-based setup**: the TV shows an address and a code; you fill in a form from a computer or phone on the same network. No typing with the remote.
- **Connection test** per DVR: tells you whether the video port, username/password and channels are correct, with clear messages.
- **Built for the remote control**: everything works with the arrow keys and the center button.
- **Optional PIN** to protect the app and its settings.
- **Lightweight**: plays only the visible page, without audio and with little memory per camera, for old or low-end TVs.

## Requirements

- **Android 7.0 or later** (Android TV, TV box, tablet or phone).
- A **Hikvision** (or compatible) DVR or NVR with **RTSP** enabled, on the same local network as the TV.
- For automatic camera names, the DVR's web service must be enabled (port 80, ISAPI). If it isn't, you can still type the channel numbers by hand.
- Other brands: as an extra, any device with RTSP can be added as *Generic* by typing its video path and channels.

> Some very old DVRs have no RTSP (they can only be viewed with iVMS/SDK); those are not supported.

## Installation

1. Download the APK from the [**Releases**](../../releases/latest) page. There are three options:

   | File | Device |
   |---|---|
   | `SentriCam-...-armeabi-v7a.apk` | Most Android TVs and TV boxes, especially older ones (32-bit). |
   | `SentriCam-...-arm64-v8a.apk` | Newer devices (64-bit). |
   | `SentriCam-...-universal.apk` | Works on any device, but is about three times larger. |

   If you're not sure which one to use, install the universal one. With `adb` you can check: `adb shell getprop ro.product.cpu.abi`.

2. Install it on the TV in one of these ways:
   - **With a USB drive** and a file manager on the TV (you need to allow "unknown sources").
   - **With adb** from a computer on the same network (enable debugging in the TV's developer options):
     ```bash
     adb connect TV_IP
     adb install -r SentriCam-...-armeabi-v7a.apk
     ```
   - **Over the network (fastest)**: share the APK over SMB or FTP and open it on the TV with an app such as CX File Explorer to install it directly.

## First-time setup

1. Open SentriCam on the TV. The **Configurar cámaras** (Set up cameras) screen appears with an address (for example `http://192.168.1.50:8080`) and a **6-digit code**.
2. From a computer or phone **connected to the same network**, open that address in a browser and enter the code.
3. Under **DVRs**, fill in one row per recorder:
   - **Nombre** (Name): whatever you want to call it (for example "Warehouse").
   - **IP** of the DVR.
   - **Puerto** (Port): the RTSP video port, usually `554`.
   - **Usuario** and **Contraseña** (username and password) of the DVR.
   - **Canales** (Channels): leave empty for all of them (analog and IP cameras), or for example `1-8, 12`. Names are taken from the DVR.
   - **Marca** (Brand): *Hikvision* for everything above. *Genérico (RTSP)* (Generic) is an extra for other brands: you type the RTSP video path (with `{canal}` instead of the channel number, for example `/cam/realmonitor?channel={canal}&subtype=0`) and the channels by hand; names and the channel list are not read from the device.
4. Press **Probar** (Test) to check the connection, then **Guardar** (Save) to add the DVR to the list. Repeat for each DVR.
5. (Optional) Create **groups** by ticking the cameras for each one.
6. Under **Pantalla** (Display), choose cameras per page, automatic page switching, quality, decoding and an optional PIN.
7. Press **Guardar configuración en la TV** (Save settings to the TV). The TV starts showing the cameras.

To change anything later, open the settings from the gear icon in the top bar (or the remote's menu key) and repeat the process. For security, browser access closes automatically after 10 minutes or when you leave that screen.

## Using the remote control

| Key | Action |
|---|---|
| Arrows | Move between cameras. At the left or right edge, change page. |
| Center button | Show the camera full screen. |
| Back | Exit full screen. |
| CH+ / CH− (or Page Up/Down) | Next or previous page. |
| Menu | Open the settings. |
| Up arrow (from the first row) | Top bar: pages, pause automatic switching, choose group or DVR, manage DVRs and settings. |

On touch screens you can also swipe sideways to change page.

## Tips

- **Create a view-only user** on each DVR (live view permission, only the channels you need) and use it in the app instead of the administrator account.
- **Use low quality (substream)** in the grid: it's the default and it's what lets you watch several cameras at once smoothly.
- **To make cameras appear faster** when changing page, set the substream's *I-frame interval* on the DVR equal to its FPS (for example 15 if it records at 15 fps).
- **If the TV freezes or reboots** when changing page or opening a camera full screen: lower the cameras per page, turn off *high quality in full screen* under **Pantalla** (Display) and, if it still happens, *hardware decoding*. On the DVR, the substream should ideally be low-resolution H.264 (for example 640×480, 15 fps).
- **Beware of wrong passwords**: Hikvision devices lock out an IP address for about 30 minutes after several failed attempts. The app does not retry when a password is rejected, to avoid triggering that lockout.

## Security and privacy

- The APK **contains no passwords**. DVR details are entered from the browser and stored **encrypted** on the TV (Android secure storage).
- The setup access only works while that screen is open, requires a 6-digit code, only accepts devices on the local network and **never returns passwords**.
- The app only accepts DVRs with a local network IP address.
- Known limitations: settings travel over HTTP inside your network when saved, and the DVRs' RTSP video is not encrypted. That's why the app is meant only as a quick option for local networks.

## Diagnostics from a computer

`tool/probar_dvr.py` tests a DVR from your PC the same way the app does: it finds the RTSP port, tests the username and password, reads the channel list and checks that video arrives. It only needs Python 3 (no extra libraries) and asks for the password without showing it. Its output is in Spanish.

```bash
python tool/probar_dvr.py 192.168.1.64 -u username
python tool/probar_dvr.py 192.168.1.64 -u username --canal 3
python tool/probar_dvr.py 192.168.1.64 --escanear    # look for RTSP on every port
python tool/probar_dvr.py 192.168.1.64 -u username --todos   # check both qualities of every channel
```

## Building from source

Requires [Flutter](https://flutter.dev) 3.41 or later and the Android SDK.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/simbolos
```

The APKs are placed in `build/app/outputs/flutter-apk/`.

**Signing**: if `android/key.properties` exists, the release APK is signed with your key; otherwise the debug key is used. To use your own, create that file (it is not committed to the repository):

```properties
storeFile=path/to/your-key.jks
storePassword=...
keyAlias=...
keyPassword=...
```

> An APK signed with a different key can't be installed over the one from Releases: you must uninstall the app first (and set it up again).

**Example configuration**: `config/config.ejemplo.json` shows the full format. During development you can copy it to `config/config.local.json` (ignored by git), fill it in and send it to the TV with:

```bash
dart run tool/cargar_config.dart TV_IP CODE
```

**Icons**: the original icon is `assets/icono/SentriCam.png`. If you change it, regenerate the Android icons with `python tool/generar_iconos.py` (requires Pillow).

## Project structure

The code, comments and file names are in Spanish.

```
lib/
  main.dart               Startup and initial screen
  modelos.dart            Settings, DVRs, cameras, groups and validation
  almacen.dart            Encrypted storage of the settings
  hikvision.dart          Channel lookup, authentication and connection tests
  servidor_config.dart    Temporary setup server (port 8080)
  pagina_web.dart         Web setup form
  importar.dart           "Configurar cámaras" screen
  cuadricula.dart         Paged grid and remote-control navigation
  vista_camara.dart       RTSP player for each camera
  administrar_dvrs.dart   DVR list and connection test on the TV
  pin.dart                PIN screen
test/                     Automated tests
tool/                     PC tools (diagnostics, config upload, icons)
config/                   Example configuration
assets/icono/             Original app icon
android/                  Android project
```

Built with [Flutter](https://flutter.dev) and [media_kit](https://github.com/media-kit/media-kit) (mpv/FFmpeg), with help from [Claude Code](https://claude.com/claude-code).

## License

SentriCam is **free software** under the [MIT License](LICENSE): you can use, copy, modify and share it freely, including for commercial purposes, as long as you keep the copyright notice. It is provided as is, without warranty.

SentriCam is not affiliated with Hikvision. Hikvision and iVMS are trademarks of their respective owners.

---

<p align="center">Developed by <b>4lanpz</b></p>
