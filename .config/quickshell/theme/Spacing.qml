pragma Singleton
import QtQuick

QtObject {
    // Spacing and margins scaled dynamically to match UI scale
    readonly property int xs: Math.round(4 * UIScale.spacingScale)
    readonly property int sm: Math.round(8 * UIScale.spacingScale)
    readonly property int md: Math.round(12 * UIScale.spacingScale)
    readonly property int lg: Math.round(16 * UIScale.spacingScale)
    readonly property int xl: Math.round(24 * UIScale.spacingScale)
    readonly property int xxl: Math.round(32 * UIScale.spacingScale)

    // Common semantic layout aliases
    readonly property int layoutSpacing: sm
    readonly property int containerMargin: lg
}
