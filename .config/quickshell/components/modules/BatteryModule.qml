import Quickshell
import QtQuick
import QtQuick.Layouts

DashboardModule {
    id: batteryModule
    displayName: "Battery"

    /**
        * AUTO-DETECT if battery is available through shared service.
        * Desktop machines with no Battery-type power_supply are auto-hidden.
     * 
        * This keeps module UI logic separate from data acquisition logic.
     */
    available: root.batteryService.available
    implicitHeight: 70

    property int batVal: root.batteryService.capacity
    property bool isCharging: root.batteryService.status === "Charging"
    property string statusText: {
        var status = root.batteryService.status
        var cap = batteryModule.batVal

        if (status === "Charging") {
            return "⚡ Charging"
        }
        if (status === "Discharging") {
            if (cap > 80) return "Discharging (Good)"
            if (cap > 20) return "Discharging"
            return "⚠ Low Battery"
        }
        if (status === "Full") {
            return "Fully Charged"
        }
        return status
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        Text {
            id: batIcon
            text: {
                var cap = batteryModule.batVal
                if (cap >= 90) return "󰁹"
                if (cap >= 80) return "󰂂"
                if (cap >= 70) return "󰂁"
                if (cap >= 60) return "󰂀"
                if (cap >= 50) return "󰁿"
                if (cap >= 40) return "󰁾"
                if (cap >= 30) return "󰁽"
                if (cap >= 20) return "󰁼"
                if (cap >= 10) return "󰁻"
                return "󰂎"
            }
            color: root.walColor2
            font.pixelSize: 32
            font.family: "JetBrainsMono Nerd Font"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                text: "Battery " + batteryModule.batVal + "%"
                color: root.walForeground
                font.pixelSize: 18
                font.family: "JetBrainsMono Nerd Font"
            }

            Text {
                id: batStatus
                text: batteryModule.statusText
                color: root.walColor8
                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"
            }
        }
    }

}
