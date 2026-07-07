pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: scaler

    // Allow override via environment variable QS_SCALE (e.g. export QS_SCALE=1.2)
    readonly property real envScale: {
        var val = parseFloat(Quickshell.env("QS_SCALE"))
        return isNaN(val) ? 1.0 : val
    }

    // Active/Primary screen representation
    readonly property ShellScreen activeScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // Adaptive resolution-based scaling factor.
    // Calculates a gentler, continuous scaling factor relative to a 1440p (1440px physical height) baseline.
    readonly property real calculatedScale: {
        if (!activeScreen || activeScreen.height <= 0) return 1.0;
        // Linear interpolation formula:
        // - 1440p (baseline): scale = 1.0
        // - 1080p (standard): scale = 0.82 (18% downscaling for smaller workspace)
        // - 1600p (16:10 laptop): scale = 1.08 (safe 8% upscaling)
        // - 2160p (4K desktop): scale = 1.36 (36% upscaling)
        var rawScale = 1.0 + (activeScreen.height - 1440.0) * 0.0005
        return Math.max(0.5, Math.min(2.0, rawScale))
    }

    // Final combined scale factor
    readonly property real scale: envScale * calculatedScale

    // Semantically split scaling factors for future-proofing (e.g. accessibility, custom settings)
    readonly property real fontScale: scale < 1.0 ? 1.1 : scale
    readonly property real spacingScale: scale
    readonly property real iconScale: scale
}
