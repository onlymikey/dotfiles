import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../theme"

DashboardModule {
    displayName: "Power Buttons"
    available: true
    implicitHeight: root.sessionService.enabled ? 110 : 90
    Behavior on implicitHeight { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }

    Column {
        anchors.centerIn: parent
        spacing: 10
        width: parent.width - 30

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 25

            PowerBtn {
                icon: Icons.powerShutdown
                iconColor: root.walColor2
                cmd: "systemctl poweroff"
            }
            PowerBtn {
                icon: Icons.powerReboot
                iconColor: root.walColor13
                cmd: "systemctl reboot"
            }
            PowerBtn {
                icon: Icons.powerLock
                iconColor: root.walColor5
                cmd: "hyprlock"
            }
            PowerBtn {
                icon: Icons.powerSuspend
                iconColor: root.walColor4
                cmd: "systemctl suspend"
            }
            PowerBtn {
                icon: Icons.powerLogout
                iconColor: root.walColor1
                cmd: "hyprctl dispatch 'hl.dsp.exit()'"
            }
        }

        // Divider
        Rectangle {
            width: parent.width
            height: 1
            color: root.walColor8
            opacity: 0.15
        }

        // Checkbox and Service Status Column
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            // Checkbox row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Rectangle {
                    width: 14
                    height: 14
                    radius: Radius.small
                    color: root.sessionService.enabled ? root.walColor2 : Qt.rgba(1, 1, 1, 0.05)
                    border.color: root.sessionService.enabled ? "transparent" : root.walColor8
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: root.walBackground
                        font.pixelSize: Typography.sizeTiny
                        font.bold: true
                        visible: root.sessionService.enabled
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.sessionService.enabled = !root.sessionService.enabled
                    }
                }

                Text {
                    text: "Restore previous session"
                    color: root.walColor8
                    font.pixelSize: Typography.sizeCaption
                    font.family: Typography.defaultFamily
                    verticalAlignment: Text.AlignVCenter
                    height: 14

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.sessionService.enabled = !root.sessionService.enabled
                    }
                }
            }

            // Service status row (Visible only when restore is enabled)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                visible: root.sessionService.enabled

                Text {
                    text: !root.sessionService.serviceInstalled ? "⚠" : "✓"
                    color: !root.sessionService.serviceInstalled ? root.walColor1 : root.walColor2
                    font.family: Typography.defaultFamily
                    font.pixelSize: Typography.sizeCaption
                    font.bold: true
                }

                Text {
                    text: !root.sessionService.serviceInstalled ? "Session Service not installed" : "Session Service installed"
                    color: root.walColor8
                    font.family: Typography.defaultFamily
                    font.pixelSize: Typography.sizeTiny
                    verticalAlignment: Text.AlignVCenter
                    height: 16
                }

                // Install Button
                Rectangle {
                    visible: !root.sessionService.serviceInstalled
                    height: 16
                    width: installText.implicitWidth + 10
                    radius: Radius.small
                    color: installMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: root.walColor8
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: installText
                        anchors.centerIn: parent
                        text: "Install Service"
                        color: root.walColor5
                        font.family: Typography.defaultFamily
                        font.pixelSize: Typography.sizeTiny
                        font.bold: true
                    }

                    MouseArea {
                        id: installMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.sessionService.installService()
                    }
                }
            }
        }
    }

    component PowerBtn: Rectangle {
        property string icon
        property color iconColor
        property string cmd
        width: 40
        height: 40
        radius: Radius.medium
        color: powerMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        Behavior on color { ColorAnimation { duration: Animations.fast } }

        Text {
            anchors.centerIn: parent
            text: icon
            color: iconColor
            font.pixelSize: Typography.sizeTitleMedium
            font.family: Typography.defaultFamily
        }

        MouseArea {
            id: powerMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cmdProc.running = true
        }

        Process {
            id: cmdProc
            command: ["bash", "-c", (root.sessionService.enabled && (icon === Icons.powerShutdown || icon === Icons.powerReboot || icon === Icons.powerLogout) ? "python3 " + root.configPath + "/services/session_helper.py capture; " : "") + cmd]
        }
    }
}
