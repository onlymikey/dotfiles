import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

DashboardModule {
    displayName: "Power Buttons"
    available: true
    implicitHeight: 50

    Row {
        anchors.centerIn: parent
        spacing: 25

        PowerBtn {
            icon: "⏻"
            iconColor: root.walColor2
            cmd: "systemctl poweroff"
        }
        PowerBtn {
            icon: "󰜉"
            iconColor: root.walColor13
            cmd: "systemctl reboot"
        }
        PowerBtn {
            icon: "󰌾"
            iconColor: root.walColor5
            cmd: "hyprlock"
        }
        PowerBtn {
            icon: "󰒲"
            iconColor: root.walColor4
            cmd: "systemctl suspend"
        }
        PowerBtn {
            icon: "󰍃"
            iconColor: root.walColor1
            cmd: "hyprctl dispatch 'hl.dsp.exit()'"
        }
    }

    component PowerBtn: Rectangle {
        property string icon
        property color iconColor
        property string cmd
        width: 40
        height: 40
        radius: 10
        color: powerMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: icon
            color: iconColor
            font.pixelSize: 18
            font.family: "JetBrainsMono Nerd Font"
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
            command: ["bash", "-c", cmd]
        }
    }
}
