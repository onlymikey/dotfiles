import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../theme"

DashboardModule {
    id: sensorModule
    displayName: "Hardware Telemetry"
    
    // Only display if there are extra sensors beyond basic CPU/RAM/Disk (like GPU, Fans, Power)
    available: {
        var s = root.sensorService
        return (s.gpuTemperature !== null || s.fanSpeed !== null || s.cpuPower !== null || s.gpuPower !== null)
    }

    implicitHeight: layoutColumn.implicitHeight + 30

    ColumnLayout {
        id: layoutColumn
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        Text {
            text: "Hardware Status"
            color: root.walForeground
            font.pixelSize: Typography.sizeBodyMedium
            font.bold: true
            font.family: Typography.defaultFamily
        }

        GridLayout {
            columns: 2
            rowSpacing: 8
            columnSpacing: 20
            Layout.fillWidth: true

            // CPU Temp
            Text {
                visible: root.sensorService.cpuTemperature !== null
                text: Icons.sensorCpu + "  CPU Temp"
                color: root.walColor8
                font.pixelSize: Typography.sizeBodySmall
                font.family: Typography.defaultFamily
            }
            Text {
                visible: root.sensorService.cpuTemperature !== null
                text: root.sensorService.cpuTemperature + "°C"
                color: root.walForeground
                font.pixelSize: Typography.sizeBodySmall
                font.bold: true
                font.family: Typography.defaultFamily
                Layout.alignment: Qt.AlignRight
            }

            // GPU Temp
            Text {
                visible: root.sensorService.gpuTemperature !== null
                text: Icons.sensorGpu + "  GPU Temp"
                color: root.walColor8
                font.pixelSize: Typography.sizeBodySmall
                font.family: Typography.defaultFamily
            }
            Text {
                visible: root.sensorService.gpuTemperature !== null
                text: root.sensorService.gpuTemperature + "°C"
                color: root.walForeground
                font.pixelSize: Typography.sizeBodySmall
                font.bold: true
                font.family: Typography.defaultFamily
                Layout.alignment: Qt.AlignRight
            }

            // SSD Temp
            Text {
                visible: root.sensorService.ssdTemperature !== null
                text: Icons.sensorSsd + "  SSD Temp"
                color: root.walColor8
                font.pixelSize: Typography.sizeBodySmall
                font.family: Typography.defaultFamily
            }
            Text {
                visible: root.sensorService.ssdTemperature !== null
                text: root.sensorService.ssdTemperature + "°C"
                color: root.walForeground
                font.pixelSize: Typography.sizeBodySmall
                font.bold: true
                font.family: Typography.defaultFamily
                Layout.alignment: Qt.AlignRight
            }

            // Fan Speed
            Text {
                visible: root.sensorService.fanSpeed !== null
                text: Icons.sensorFan + "  Fan Speed"
                color: root.walColor8
                font.pixelSize: Typography.sizeBodySmall
                font.family: Typography.defaultFamily
            }
            Text {
                visible: root.sensorService.fanSpeed !== null
                text: root.sensorService.fanSpeed + " RPM"
                color: root.walForeground
                font.pixelSize: Typography.sizeBodySmall
                font.bold: true
                font.family: Typography.defaultFamily
                Layout.alignment: Qt.AlignRight
            }

            // CPU Power
            Text {
                visible: root.sensorService.cpuPower !== null
                text: Icons.sensorPower + "  CPU Power"
                color: root.walColor8
                font.pixelSize: Typography.sizeBodySmall
                font.family: Typography.defaultFamily
            }
            Text {
                visible: root.sensorService.cpuPower !== null
                text: root.sensorService.cpuPower + " W"
                color: root.walForeground
                font.pixelSize: Typography.sizeBodySmall
                font.bold: true
                font.family: Typography.defaultFamily
                Layout.alignment: Qt.AlignRight
            }

            // GPU Power
            Text {
                visible: root.sensorService.gpuPower !== null
                text: Icons.sensorPower + "  GPU Power"
                color: root.walColor8
                font.pixelSize: Typography.sizeBodySmall
                font.family: Typography.defaultFamily
            }
            Text {
                visible: root.sensorService.gpuPower !== null
                text: root.sensorService.gpuPower + " W"
                color: root.walForeground
                font.pixelSize: Typography.sizeBodySmall
                font.bold: true
                font.family: Typography.defaultFamily
                Layout.alignment: Qt.AlignRight
            }
        }
    }
}
