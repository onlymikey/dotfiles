# My Hyprland + Quickshell dotfiles!

This is my personal rice for **Hyprland** and **Quickshell** (Arch Linux). I am sharing it in case anyone finds it useful as a base, reference, or inspiration for their own Wayland desktop.

---

## Credits & Attribution Note

**The base of this rice was not created by me.** I adapted (and frankly, "stole") it from a user on r/unixporn some time ago, but unfortunately, I can no longer remember their name. 

I do not want to take full credit for this project, as the gorgeous foundation belongs to them. If you are the original creator, or if you know who created the original config, please open an Issue with their name and a link so I can properly credit them here.

---

## Highlights & Features

### ⚙️ System Settings Center (`SUPER + I` / `SUPER + P`)
*   **Display & Projection Manager**: Real-time monitor discovery and configuration. Switch dynamically between **Extend**, **Mirror**, **Primary Only**, and **External Only** projection layouts.
*   **Resolution & Refresh Rate Tuning**: Preserves custom overclocked refresh rates (e.g., 180Hz, 73Hz) with intelligent priority selection (**High Refresh Rate** vs. **High Resolution**) and a 10-second safety reversion fallback timer.
*   **Shell Internationalization (I18n)**: Reactive, zero-restart instant language switcher between **Spanish (LatAm)** and **English (US)** across all panels and menus.
*   **Keyboard Layout Switcher**: One-click switching between **US International** (dead keys/alt-gr), **Spanish (LatAm)**, **Spanish (Spain)**, and **US Standard**.
*   **System Information & Typography**: Live system specs and high-DPI/standard display status.

### 📱 Connected Devices — Android Integration (`SUPER + C` / `SUPER + SHIFT + C`)
*   **Top Bar Notch Pill**: Displays live phone connectivity status with an interactive indicator directly on the top bar.
*   **Mobile Status Popup**: Elegant dark panel showcasing phone model, live battery percentage with charging indicator, cellular network type (4G LTE / 5G / Wi-Fi), a 4-bar signal strength meter, and notification counts.
*   **Screen Mirroring & Control (`scrcpy`)**: High-performance, low-latency screen mirroring with seamless mouse and keyboard input in a centered floating window (`440x920`). Press `SUPER + SHIFT + C` to launch or focus the window instantly.
*   **Find Phone (`KDE Connect`)**: Trigger an audible ring on your device directly from the desktop.
*   **Decoupled Architecture**: ADB debugging and KDE Connect operate independently. If ADB is disabled or unauthorized, KDE Connect continues handling clipboard, files, and ringing while presenting clear contextual guidance.

### 🚀 Application Launcher (`SUPER + R`)
*   **Unified Discovery**: Automatically indexes native desktop applications (`/usr/share/applications`, `~/.local/share/applications`), Flatpak packages (`/var/lib/flatpak/exports`, `~/.local/share/flatpak/exports`), and standalone AppImages (`~/Applications`, `~/AppImages`).
*   **Sanitized Execution**: Automatically cleans FreeDesktop field codes and Flatpak forwarding wrappers (`@@u @@`, `--file-forwarding`, `%u`) ensuring all sandboxed and bundled apps launch reliably.
*   **Instant Updates**: Built-in `inotify` watcher refreshes the app list the instant an app or package is installed or removed.

### 🔊 Reactive Audio & "Modo Desquiciado"
*   **Volume Overamplification**: Supports boosting audio volume up to **150%** ("Modo Desquiciado") with an intuitive safety divider at 100%.
*   **Zero-Polling Event Daemons**: Listens to PipeWire/WirePlumber events reactively through `pactl subscribe` with sub-millisecond responsiveness.
*   **Seamless Bluetooth Routing**: Automatically switches cards to high-fidelity audio profiles (A2DP) upon connection.

### 🔔 Notification Center & Popups (`SUPER + N`)
*   **Application Grouping**: Cleanly groups notifications by application with expandable summary cards and inline action buttons.
*   **Do Not Disturb**: Quick toggle with visual indicator in the top bar.

### 🎨 Pixel-Perfect UI & Reactive Design
*   **Adaptive 1080p Baseline**: Tuned base scale (`1080p = 1.0x`) with sub-pixel readability floors to ensure crisp, razor-sharp typography on standard 1080p monitors.
*   **Fullscreen Auto-Hiding**: Wayland layers automatically hide the top bar when playing fullscreen games or browser videos (YouTube, Twitch), restoring it smoothly when exiting.
*   **Dynamic Theming**: Dynamic color palette powered by `pywal` synchronized across Quickshell, SwayNC, and terminal kitty.

---

## Architecture

The system enforces a clean separation of concerns:

```
Compositor / System Daemons (Hyprland, PipeWire, BlueZ, NetworkManager, ADB)
       ↓
Reactive Python Backend Daemons (D-Bus, IPC sockets, inotify)
       ↓
QML Services (Single reactive source of truth)
       ↓
Declarative UI Panels & Widgets (Quickshell)
```

---

## Keybindings Cheatsheet

| Keybinding | Action |
| :--- | :--- |
| `SUPER + RETURN` | Terminal (`kitty`) |
| `SUPER + SHIFT + RETURN` | Floating Terminal |
| `SUPER + R` | Application Launcher |
| `SUPER + Q` | Close Active Window |
| `SUPER + F` | Fullscreen Window |
| `SUPER + SHIFT + F` | Toggle Floating Window |
| `SUPER + A` | Modular Dashboard |
| `SUPER + I` | System Settings Center |
| `SUPER + P` / `XF86Display` | Displays & Projection Settings |
| `SUPER + C` | Connected Devices (Android Popup) |
| `SUPER + SHIFT + C` | Mirror & Focus Phone Screen (`scrcpy`) |
| `SUPER + M` | Music Panel |
| `SUPER + N` | Notification Center |
| `SUPER + W` | Wallpaper Selector |
| `SUPER + SHIFT + W` | Random Wallpaper |
| `SUPER + ESCAPE` | Lock Screen (`hyprlock`) |

---

## Dependencies

### Core & Compositor
*   `hyprland` (Hyprlua or standard Hyprland)
*   `quickshell` (Git or release package)
*   `python`, `python-gobject`, `python-dbus`
*   Fonts: `ttf-jetbrains-mono`, `ttf-jetbrains-mono-nerd`

### Audio & Connectivity
*   `pipewire`, `wireplumber` (Audio routing)
*   `networkmanager` (Networking)
*   `bluez`, `bluez-utils` (Bluetooth)
*   `brightnessctl` (Brightness control)
*   `socat`, `inotify-tools` (IPC events & file watching)

### Mobile & Device Integration (Optional but Recommended)
*   `scrcpy` (High-definition Android screen mirroring)
*   `android-tools` (`adb` debugging)
*   `kdeconnect` (Phone notifications, clipboard, ringing, file sharing)

### Utilities & Theming (Optional)
*   `python-pywal` and `awww` / `swww` (Dynamic colors and wallpapers)
*   `cliphist` and `wl-clipboard` (Clipboard history)
*   `hyprlock` (Screen locker)
*   `rmpc` (TUI music player)
*   `gpu-screen-recorder` / `gsr-ui` (ShadowPlay-style screen recorder)

---

## Installation

You can inspect, install dependencies, and deploy the configuration using the installer:

```bash
git clone https://github.com/onlymikey/dotfiles
cd dotfiles
chmod +x install.sh
./install.sh
```

The installer detects existing configurations and backs them up safely under:
*   `~/.config/hypr.backup-YYYYMMDD-HHMMSS`
*   `~/.config/quickshell.backup-YYYYMMDD-HHMMSS`

---
