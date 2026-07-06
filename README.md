# My Hyprland + Quickshell dotfiles!

This is my personal rice for Hyprland and Quickshell. I am sharing it in case anyone finds it useful as a base or inspiration for their own Wayland desktop.

---

## Credits & Attribution Note

**The base of this rice was not created by me.** I adapted (and frankly, "stole") it from a user on r/unixporn some time ago, but unfortunately, I can no longer remember their name. 

I do not want to take full credit for this project, as the gorgeous foundation belongs to them. If you are the original creator, or if you know who created the original config, please open an Issue with their name and a link so I can properly credit them here.

---

## Features

*   **Modular Dashboard**: Quick access to volume, brightness, power buttons, and system statistics.
*   **Notification Center**: Groups notifications by application with support for expand/collapse animations and action buttons.
*   **Launcher**: Fast application launcher with instant automatic reload on changes.
*   **Wi-Fi & Bluetooth**: Interactive lists to connect to networks and devices.
*   **Calendar & Clipboard**: Simple calendar panel and clipboard manager using `cliphist`.
*   **Session Restore**: Saves window position, size, workspace, and layout when shutting down, restoring them dynamically on login.
*   **Systemd Integration**: Optional `--user` service to automatically capture layout states on shutdown/logout.
*   **Responsive Layout**: Relative typography and spacing units inspired by KDE Kirigami.

---

## Architecture

A simple design keeps the UI separated from system-level logic:

```
Compositor / System Daemons
       ↓
Auxiliary Scripts (Python, bash)
       ↓
QML Services (Single source of truth)
       ↓
UI (Declarative QML)
```

---

## Session Restore

Preserves the layout of Hyprland windows across shutdowns.
*   **How it works**: Reads `/proc/<pid>/cmdline` to identify running apps. On login, it opens them and uses Hyprland's event socket (`.socket2.sock`) to restore their workspace, monitor, scale, and geometry.
*   **Systemd Service**: Can be enabled from the Dashboard. If not installed, a one-click button will appear to copy and enable the user-level systemd service.

---

## Dependencies

### Required
*   `hyprland`, `quickshell`
*   `python`
*   `wireplumber`, `pipewire` (Audio)
*   `brightnessctl` (Brightness)
*   `networkmanager` (Networking)
*   `bluez`, `bluez-utils` (Bluetooth)
*   `socat`, `inotify-tools` (Events)
*   Fonts: `ttf-jetbrains-mono`, `ttf-jetbrains-mono-nerd`

### Optional
*   `python-pywal` and `awww` (Colors and wallpapers)
*   `cliphist` and `wl-clipboard` (Clipboard)
*   `hyprlock` (Screen locker)
*   `rmpc` (TUI music player)
*   `gpu-screen-recorder` (Screen recorder)

---

## Installation

You can install dependencies and deploy the files using the interactive installer:

```bash
git clone https://github.com/onlymikey/dotfiles
cd dotfiles
chmod +x install.sh
./install.sh
```

The installer is safe. If existing configurations are detected, it renames and backs them up under:
*   `~/.config/hypr.backup-YYYYMMDD-HHMMSS`
*   `~/.config/quickshell.backup-YYYYMMDD-HHMMSS`

---

