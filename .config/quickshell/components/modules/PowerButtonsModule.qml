import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../theme"

DashboardModule {
    displayName: "Power Buttons"
    available: true
    implicitHeight: 65

    Row {
        anchors.centerIn: parent
        spacing: root.batteryService.available ? 16 : 25

        PowerBtn {
            icon: Icons.powerShutdown
            label: I18n.s.pwr_shutdown
            iconColor: root.walColor2
            cmd: "systemctl poweroff"
        }
        PowerBtn {
            icon: Icons.powerReboot
            label: I18n.s.pwr_reboot
            iconColor: root.walColor13
            cmd: "systemctl reboot"
        }
        PowerBtn {
            icon: Icons.powerLock
            label: I18n.s.pwr_lock
            iconColor: root.walColor5
            cmd: "pidof hyprlock >/dev/null || hyprlock"
        }
        PowerBtn {
            icon: Icons.powerSuspend
            label: I18n.s.pwr_suspend
            iconColor: root.walColor4
            cmd: "(pidof hyprlock >/dev/null || hyprlock &) && sleep 0.3 && systemctl suspend"
        }
        PowerBtn {
            visible: root.batteryService.available
            icon: Icons.powerHibernate
            label: I18n.s.pwr_hibernate
            iconColor: root.walColor13
            cmd: "(pidof hyprlock >/dev/null || hyprlock &) && sleep 0.3 && if [ \"$(wc -l < /proc/swaps 2>/dev/null || echo 0)\" -gt 1 ] && grep -q disk /sys/power/state 2>/dev/null; then systemctl hibernate; else notify-send -u normal -a 'Power' 'Hibernación no disponible' 'No hay swap activa; suspendiendo en su lugar...' && systemctl suspend; fi"
        }
        PowerBtn {
            icon: Icons.powerLogout
            label: I18n.isSpanish ? "Cerrar sesión" : "Log out"
            iconColor: root.walColor1
            cmd: "hyprctl eval 'hl.dispatch(hl.dsp.exit())'"
        }
    }

    component PowerBtn: Rectangle {
        property string icon
        property string label: ""
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

        ToolTip.visible: powerMa.containsMouse && label !== ""
        ToolTip.text: label
        ToolTip.delay: 300

        MouseArea {
            id: powerMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.closeAllPanels()
                cmdProc.running = true
            }
        }

        Process {
            id: cmdProc
            command: ["bash", "-c", cmd]
        }
    }
}
