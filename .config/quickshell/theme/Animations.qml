pragma Singleton
import QtQuick

QtObject {
    // Animation durations in milliseconds (time durations should NOT scale with DPI)
    readonly property int instant: 0
    readonly property int fast: 150
    readonly property int normal: 300
    readonly property int slow: 800

    // Standard Easing curves for animations
    readonly property int easingType: Easing.OutCubic
}
