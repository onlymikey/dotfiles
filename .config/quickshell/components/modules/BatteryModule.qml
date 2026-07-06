import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../theme"

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
            return Icons.batteryChargingText + " Charging"
        }
        if (status === "Discharging") {
            if (cap > 80) return "Discharging (Good)"
            if (cap > 20) return "Discharging"
            return Icons.batteryWarning + " Low Battery"
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
                if (cap >= 90) return Icons.battery100
                if (cap >= 80) return Icons.battery90
                if (cap >= 70) return Icons.battery80
                if (cap >= 60) return Icons.battery70
                if (cap >= 50) return Icons.battery60
                if (cap >= 40) return Icons.battery50
                if (cap >= 30) return Icons.battery40
                if (cap >= 20) return Icons.battery30
                if (cap >= 10) return Icons.battery20
                return Icons.batteryEmpty
            }
            color: root.walColor2
            font.pixelSize: Typography.sizeDisplaySmall
            font.family: Typography.defaultFamily
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                text: "Battery " + batteryModule.batVal + "%"
                color: root.walForeground
                font.pixelSize: Typography.sizeTitleMedium
                font.family: Typography.defaultFamily
            }

            Text {
                id: batStatus
                text: batteryModule.statusText
                color: root.walColor8
                font.pixelSize: Typography.sizeNormal
                font.family: Typography.defaultFamily
            }
        }
    }

}

