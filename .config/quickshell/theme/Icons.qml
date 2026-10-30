pragma Singleton
import QtQuick

QtObject {
    // Media controls
    readonly property string mediaPrev: "󰒮"
    readonly property string mediaNext: "󰒭"
    readonly property string mediaPlay: "󰐊"
    readonly property string mediaPause: "󰏤"
    readonly property string mediaGif: "󰏫"

    // System panels & modules
    readonly property string launcherTabApps: "󰀻"
    readonly property string launcherTabWallpapers: "󰸉"
    readonly property string launcherTabClipboard: "󰅍"
    readonly property string calendar: "󰵙"
    readonly property string profileEdit: "󰏫"
    readonly property string arch: "󰣇"
    readonly property string dashboard: "󰕮"
    readonly property string settings: "󰒓"
    readonly property string language: "󰗊"
    readonly property string keyboard: "󰌌"
    readonly property string appearance: "󰔎"
    readonly property string info: "󰋼"
    readonly property string listNavVertical: "↑↓"
    readonly property string listNavAll: "←→↑↓"
    readonly property string listNavHorizontal: "←→"
    readonly property string keyboardEnter: "↵"
    readonly property string bullet: "•"
    readonly property string separatorDot: " • "
    readonly property string vpn: "󰖂"
    readonly property string apply: "󰸞"

    // Notifications
    readonly property string notificationActive: "󰂚"
    readonly property string notificationDnd: "󰂛"
    readonly property string notificationDefaultApp: "󰵅"
    readonly property string notificationCenterHeader: "󰎟"

    // Power operations
    readonly property string powerShutdown: "⏻"
    readonly property string powerReboot: "󰜉"
    readonly property string powerLock: "󰌾"
    readonly property string powerSuspend: "󰒲"
    readonly property string powerHibernate: "󰤄"
    readonly property string powerLogout: "󰍃"

    // Power Profiles
    readonly property string profileNotification: "󰂚"
    readonly property string profilePerformance: "󰓅"
    readonly property string profileBalanced: "󰾅"
    readonly property string profilePowerSaver: "󰌪"
    readonly property string profileAc: "󰚥"
    readonly property string profileDefault: "󰓎"

    // Control buttons
    readonly property string close: "󰅖"
    readonly property string trash: "󰆴"
    readonly property string check: "󰄬"
    readonly property string add: "󰐕"
    readonly property string remove: "󰅖"
    readonly property string arrowRight: "→"
    readonly property string arrowLeft: "←"
    readonly property string chevronLeft: "󰁍"
    readonly property string chevronRight: "󰁔"
    readonly property string chevronDown: "󰅁"
    readonly property string chevronUp: "󰅂"
    readonly property string refresh: "󰑐"
    readonly property string refreshing: "󰑓"

    // Sensors
    readonly property string sensorCpu: ""
    readonly property string sensorGpu: "󰢮"
    readonly property string sensorSsd: "󰋊"
    readonly property string sensorFan: "󰈐"
    readonly property string sensorPower: ""

    // Audio
    readonly property string audioMute: "󰝟"
    readonly property string audioVolumeLow: "󰕿"
    readonly property string audioVolumeMedium: "󰖀"
    readonly property string audioVolumeHigh: "󰕾"
    
    // Audio Devices (semantic)
    readonly property string audioDeviceMicrophone: "󰏫"
    readonly property string audioDeviceInput: "󰍬"
    readonly property string audioDeviceDisplay: "󰍹"
    readonly property string audioDeviceHeadphones: "󰋋"
    readonly property string audioDeviceSpeakers: "󰓃"

    // Monitors & Display
    readonly property string monitor: "󰍹"
    readonly property string monitorMultiple: "󰍺"
    readonly property string monitorMirror: "󰍸"
    readonly property string monitorLaptop: "󰌢"
    readonly property string monitorSparkle: "auto"
    readonly property string monitorHz: "󰓅"
    readonly property string monitorRes: "󰹑"

    // Bluetooth
    readonly property string bluetoothEnabled: "󰂯"
    readonly property string bluetoothConnected: "󰂱"
    readonly property string bluetoothDisabled: "󰂲"

    // Wifi
    readonly property string wifiAirplaneMode: "󰀝"
    readonly property string wifiEthernet: "󰈀"
    readonly property string wifiSecure: "󰌾"
    readonly property string wifiSignal0: "󰤭"
    readonly property string wifiSignal1: "󰤟"
    readonly property string wifiSignal2: "󰤢"
    readonly property string wifiSignal3: "󰤥"
    readonly property string wifiSignal4: "󰤨"
    readonly property string wifiSignalNone: "󰤭"

    // Battery states
    readonly property string batteryCharging: "󱐋"
    readonly property string batteryChargingText: "⚡"
    readonly property string batteryWarning: "⚠"
    readonly property string battery100: "󰁹"
    readonly property string battery90: "󰂂"
    readonly property string battery80: "󰂁"
    readonly property string battery70: "󰂀"
    readonly property string battery60: "󰁿"
    readonly property string battery50: "󰁾"
    readonly property string battery40: "󰁽"
    readonly property string battery30: "󰁼"
    readonly property string battery20: "󰁻"
    readonly property string battery10: "󰂎"
    readonly property string batteryEmpty: "󰂎"

    // Phone / Connected Devices
    readonly property string phone: "󰄜"
    readonly property string phoneRing: "󰄨"
    readonly property string phoneMirror: "󰄇"
    readonly property string phoneSignal: "󰓒"
    readonly property string phoneMessage: "󰍩"
    readonly property string phoneTarget: "󰐴"
}
