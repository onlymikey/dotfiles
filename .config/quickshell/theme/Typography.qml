pragma Singleton
import QtQuick

QtObject {
    // Families
    readonly property string defaultFamily: "JetBrainsMono Nerd Font"
    readonly property string monospaceFamily: "JetBrainsMono Nerd Font"

    // Font weights
    readonly property int weightLight: Font.Light
    readonly property int weightNormal: Font.Normal
    readonly property int weightMedium: Font.Medium
    readonly property int weightDemiBold: Font.DemiBold
    readonly property int weightBold: Font.Bold

    // Font sizes with non-HiDPI legibility floors so small text is never blurry or sub-pixel on 1080p
    readonly property int sizeSuperTiny: Math.max(UIScale.isLowDpi ? 9 : 8, Math.round(9 * UIScale.fontScale))
    readonly property int sizeTiny: Math.max(UIScale.isLowDpi ? 11 : 9, Math.round(11 * UIScale.fontScale))
    readonly property int sizeCaption: Math.max(UIScale.isLowDpi ? 12 : 10, Math.round(12 * UIScale.fontScale))
    readonly property int sizeSmall: Math.max(UIScale.isLowDpi ? 12 : 11, Math.round(12 * UIScale.fontScale))
    readonly property int sizeBodySmall: Math.max(UIScale.isLowDpi ? 13 : 12, Math.round(13 * UIScale.fontScale))
    readonly property int sizeNormal: Math.round(14 * UIScale.fontScale)
    readonly property int sizeBodyMedium: Math.round(15 * UIScale.fontScale)
    readonly property int sizeBodyLarge: Math.round(16 * UIScale.fontScale)
    readonly property int sizeNormalLarge: Math.round(17 * UIScale.fontScale)
    readonly property int sizeTitleSmall: Math.round(18 * UIScale.fontScale)
    readonly property int sizeTitleMedium: Math.round(20 * UIScale.fontScale)
    readonly property int sizeTitleLarge: Math.round(22 * UIScale.fontScale)
    readonly property int sizeHeadingSmall: Math.round(24 * UIScale.fontScale)
    readonly property int sizeHeadingLarge: Math.round(28 * UIScale.fontScale)
    readonly property int sizeDisplaySmall: Math.round(32 * UIScale.fontScale)
    readonly property int sizeDisplayLarge: Math.round(40 * UIScale.fontScale)
    readonly property int sizeHuge: Math.round(48 * UIScale.fontScale)
}
