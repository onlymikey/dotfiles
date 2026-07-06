pragma Singleton
import QtQuick

QtObject {
    // Border radii scaled dynamically to match UI scale
    readonly property int small: Math.round(6 * UIScale.spacingScale)
    readonly property int mediumSmall: Math.round(8 * UIScale.spacingScale)
    readonly property int medium: Math.round(10 * UIScale.spacingScale)
    readonly property int large: Math.round(12 * UIScale.spacingScale)
    readonly property int extraLarge: Math.round(16 * UIScale.spacingScale)
    readonly property int panel: Math.round(20 * UIScale.spacingScale)
}
