pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: scaler

    // Allow override via environment variable QS_SCALE (e.g. export QS_SCALE=1.2)
    readonly property real envScale: {
        var val = parseFloat(Quickshell.env("QS_SCALE"))
        return isNaN(val) ? 1.0 : val
    }

    // Active/Focused screen representation (tracks Hyprland focusedMonitor dynamically)
    readonly property ShellScreen activeScreen: {
        var monName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        if (monName !== "") {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === monName) {
                    return Quickshell.screens[i]
                }
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    // Detect non-HiDPI screens (standard 1x scale / ~80-110 PPI) to enforce minimum font legibility
    readonly property bool isLowDpi: !activeScreen || activeScreen.devicePixelRatio <= 1.15

    function scaleForScreen(scr) {
        if (!scr || scr.height <= 0) return 1.0
        var h = scr.height
        var raw = 1.0
        if (h > 1080) {
            // Gentle upscaling above 1080p (e.g. 1440p -> ~1.13, 1600p -> ~1.18, 2160p -> ~1.38)
            raw = 1.0 + (h - 1080.0) * 0.00035
        } else if (h < 1080) {
            // Gentle downscaling below 1080p, clamped to 0.90 so UI never becomes illegible
            raw = 1.0 - (1080.0 - h) * 0.00025
        }
        return Math.max(0.90, Math.min(2.0, raw))
    }

    // Adaptive resolution-based scaling factor using 1080p (1080px logical height) as 1.0 baseline.
    readonly property real calculatedScale: scaleForScreen(activeScreen)

    // Final combined scale factor
    readonly property real scale: envScale * calculatedScale

    // Semantically unified scaling factors
    readonly property real fontScale: scale
    readonly property real spacingScale: scale
    readonly property real iconScale: scale
}
