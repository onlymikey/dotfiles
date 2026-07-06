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

    // Font sizes (common values: 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 26, 32, 40, 48)
    readonly property int sizeSuperTiny: Math.round(7 * UIScale.fontScale)
    readonly property int sizeTiny: Math.round(8 * UIScale.fontScale)
    readonly property int sizeCaption: Math.round(9 * UIScale.fontScale)
    readonly property int sizeSmall: Math.round(10 * UIScale.fontScale)
    readonly property int sizeBodySmall: Math.round(11 * UIScale.fontScale)
    readonly property int sizeNormal: Math.round(12 * UIScale.fontScale)
    readonly property int sizeBodyMedium: Math.round(13 * UIScale.fontScale)
    readonly property int sizeBodyLarge: Math.round(14 * UIScale.fontScale)
    readonly property int sizeNormalLarge: Math.round(15 * UIScale.fontScale)
    readonly property int sizeTitleSmall: Math.round(16 * UIScale.fontScale)
    readonly property int sizeTitleMedium: Math.round(18 * UIScale.fontScale)
    readonly property int sizeTitleLarge: Math.round(20 * UIScale.fontScale)
    readonly property int sizeHeadingSmall: Math.round(22 * UIScale.fontScale)
    readonly property int sizeHeadingLarge: Math.round(26 * UIScale.fontScale)
    readonly property int sizeDisplaySmall: Math.round(32 * UIScale.fontScale)
    readonly property int sizeDisplayLarge: Math.round(40 * UIScale.fontScale)
    readonly property int sizeHuge: Math.round(48 * UIScale.fontScale)
}
