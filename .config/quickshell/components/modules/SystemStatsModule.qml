import Quickshell
import QtQuick
import QtQuick.Layouts

DashboardModule {
    id: statsModule
    displayName: "System Stats"
    available: true
    implicitHeight: 140

    property int cpuVal: root.sensorService.cpuUsage
    property int ramVal: root.sensorService.ramUsage
    property int diskVal: root.sensorService.diskUsage

    Row {
        anchors.centerIn: parent
        spacing: 30

        CircularStat {
            label: "CPU"
            icon: ""
            barColor: root.walColor1
            value: statsModule.cpuVal
            extraInfo: root.sensorService.cpuTemperature !== null ? root.sensorService.cpuTemperature + "°C" : ""
        }

        CircularStat {
            label: "RAM"
            icon: ""
            barColor: root.walColor5
            value: statsModule.ramVal
            extraInfo: ""
        }

        CircularStat {
            label: "DISK"
            icon: ""
            barColor: root.walColor4
            value: statsModule.diskVal
            extraInfo: root.sensorService.ssdTemperature !== null ? root.sensorService.ssdTemperature + "°C" : ""
        }
    }

    component CircularStat: Item {
        property string label
        property string icon
        property color barColor
        property int value
        property string extraInfo: ""
        width: 90
        height: 110

        Column {
            anchors.centerIn: parent
            spacing: 5

            Item {
                width: 70
                height: 70
                anchors.horizontalCenter: parent.horizontalCenter

                Canvas {
                    anchors.fill: parent
                    property int statValue: value
                    onStatValueChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.lineWidth = 5
                        ctx.lineCap = "round"
                        ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.3)
                        ctx.beginPath()
                        ctx.arc(35, 35, 32, 0, 2 * Math.PI)
                        ctx.stroke()
                        ctx.strokeStyle = barColor
                        ctx.beginPath()
                        ctx.arc(35, 35, 32, -Math.PI / 2, -Math.PI / 2 + (statValue / 100) * 2 * Math.PI)
                        ctx.stroke()
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: icon
                        color: barColor
                        font.pixelSize: 16
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: value + "%"
                        color: root.walForeground
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: label
                    color: root.walColor8
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"
                }

                Text {
                    visible: extraInfo !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: extraInfo
                    color: root.walColor8
                    font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"
                }
            }
        }
    }
}
