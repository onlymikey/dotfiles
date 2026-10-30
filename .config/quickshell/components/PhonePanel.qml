import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"

PanelWindow {
    id: phoneWindow
    screen: root.panelScreen
    visible: root.phoneVisible || slideAnim.running
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    anchors { top: true; left: true; right: true }
    margins {
        top: root.phoneVisible ? Math.round(44 * UIScale.scale) : -Math.round(450 * UIScale.scale)
        left: 0
        right: 0
    }
    implicitHeight: Math.round(420 * UIScale.scale)
    color: "transparent"

    focusable: true
    WlrLayershell.keyboardFocus: root.phoneVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Behavior on margins.top {
        NumberAnimation {
            id: slideAnim
            duration: Animations.normal
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: root
        function onPhoneVisibleChanged() {
            if (root.phoneVisible) {
                focusTimer.start()
                if (root.phoneService) root.phoneService.refresh()
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: phoneFocusAnchor.forceActiveFocus()
    }

    FocusScope {
        id: phoneFocusScope
        anchors.fill: parent
        focus: root.phoneVisible
        enabled: root.phoneVisible

        Item {
            id: phoneFocusAnchor
            focus: true
            Keys.onEscapePressed: root.panelManager.close("phone")
        }

        // Click outside backdrop to close
        MouseArea {
            anchors.fill: parent
            z: 0
            onClicked: root.panelManager.close("phone")
        }

        // Popup Container matching Shell palette
        Rectangle {
            id: panelCard
            z: 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: Math.round(490 * UIScale.scale)
            implicitHeight: contentCol.implicitHeight + Math.round(36 * UIScale.scale)
            radius: Radius.panel
            color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.88)
            border.color: Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.22)
            border.width: 1

            MouseArea {
                anchors.fill: parent
                // Eat clicks so clicking inside doesn't trigger backdrop close
                onClicked: {}
            }

            Column {
                id: contentCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Math.round(18 * UIScale.scale)
                spacing: Math.round(14 * UIScale.scale)

                // Header Row: Phone Icon + Title + Close Button
                RowLayout {
                    width: parent.width

                    Row {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.phone
                            color: root.walColor2
                            font.pixelSize: Typography.sizeTitleMedium
                            font.family: Typography.defaultFamily
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.s.cd_title
                            color: root.walForeground
                            font.pixelSize: Typography.sizeTitleSmall
                            font.bold: true
                            font.family: Typography.defaultFamily
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Close button
                    Rectangle {
                        width: Math.round(30 * UIScale.scale)
                        height: width
                        radius: width / 2
                        color: closeMA.containsMouse ? Qt.rgba(root.walColor2.r, root.walColor2.g, root.walColor2.b, 0.2) : Qt.rgba(root.walColor0.r, root.walColor0.g, root.walColor0.b, 0.45)
                        border.color: Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.2)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: Icons.close
                            color: closeMA.containsMouse ? root.walForeground : root.walColor8
                            font.pixelSize: Typography.sizeBodySmall
                            font.family: Typography.defaultFamily
                        }

                        MouseArea {
                            id: closeMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.panelManager.close("phone")
                        }
                    }
                }

                // Main Device Card
                Rectangle {
                    width: parent.width
                    implicitHeight: deviceCol.implicitHeight + Math.round(32 * UIScale.scale)
                    radius: Radius.large
                    color: Qt.rgba(0, 0, 0, 0.28)
                    border.color: Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.18)
                    border.width: 1

                    Column {
                        id: deviceCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Math.round(16 * UIScale.scale)
                        spacing: Math.round(16 * UIScale.scale)

                        // Top of Card: Device Title & Status + Action Buttons
                        RowLayout {
                            width: parent.width

                            Column {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    text: (root.phoneService && root.phoneService.deviceName) ? root.phoneService.deviceName : "Teléfono Android"
                                    color: root.walForeground
                                    font.pixelSize: Typography.sizeTitleMedium
                                    font.bold: true
                                    font.family: Typography.defaultFamily
                                }

                                Row {
                                    spacing: 6
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 7
                                        height: 7
                                        radius: 3.5
                                        color: (root.phoneService && root.phoneService.connected) ? root.walColor2 : root.walColor8
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            if (!root.phoneService || !root.phoneService.hasDevice) return I18n.s.cd_offline
                                            if (root.phoneService.connected) {
                                                return I18n.s.cd_connected_via.replace("%1", root.phoneService.connectionType)
                                            }
                                            return I18n.s.cd_offline
                                        }
                                        color: root.walColor8
                                        font.pixelSize: Typography.sizeTiny
                                        font.family: Typography.defaultFamily
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Action buttons
                            Row {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 10

                                // 1. Scrcpy Screen Mirror button
                                Rectangle {
                                    id: scrcpyBtn
                                    width: Math.round(38 * UIScale.scale)
                                    height: width
                                    radius: width / 2
                                    readonly property bool canUse: root.phoneService && root.phoneService.canScrcpy
                                    readonly property bool isRunning: root.phoneService && root.phoneService.scrcpyRunning

                                    color: {
                                        if (isRunning) return Qt.rgba(root.walColor2.r, root.walColor2.g, root.walColor2.b, 0.25)
                                        if (scrcpyMA.containsMouse && canUse) return Qt.rgba(root.walColor2.r, root.walColor2.g, root.walColor2.b, 0.15)
                                        return Qt.rgba(root.walColor0.r, root.walColor0.g, root.walColor0.b, 0.5)
                                    }
                                    border.color: isRunning ? root.walColor2 : (scrcpyMA.containsMouse && canUse ? root.walColor2 : Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.22))
                                    border.width: isRunning ? 2 : 1
                                    opacity: canUse ? 1.0 : 0.35

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.phoneMirror
                                        color: scrcpyBtn.isRunning ? root.walColor2 : (scrcpyBtn.canUse ? root.walForeground : root.walColor8)
                                        font.pixelSize: Typography.sizeBodyLarge
                                        font.family: Typography.defaultFamily
                                    }

                                    MouseArea {
                                        id: scrcpyMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: scrcpyBtn.canUse ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                        onClicked: {
                                            if (scrcpyBtn.canUse && root.phoneService) {
                                                root.phoneService.toggleScrcpy()
                                            }
                                        }
                                    }

                                    // Simple custom tooltip on hover
                                    Rectangle {
                                        id: scrcpyTip
                                        visible: scrcpyMA.containsMouse
                                        z: 10
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: 8
                                        anchors.right: parent.right
                                        width: scrcpyTipText.implicitWidth + 14
                                        height: scrcpyTipText.implicitHeight + 8
                                        radius: Radius.small
                                        color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.95)
                                        border.color: Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.3)
                                        border.width: 1

                                        Text {
                                            id: scrcpyTipText
                                            anchors.centerIn: parent
                                            text: {
                                                if (scrcpyBtn.isRunning) return I18n.s.cd_scrcpy_running
                                                if (scrcpyBtn.canUse) return I18n.s.cd_scrcpy_btn
                                                return I18n.s.cd_scrcpy_disabled
                                            }
                                            color: root.walForeground
                                            font.pixelSize: Typography.sizeTiny
                                            font.family: Typography.defaultFamily
                                        }
                                    }
                                }

                                // 2. Find Phone Ring button
                                Rectangle {
                                    id: ringBtn
                                    width: Math.round(38 * UIScale.scale)
                                    height: width
                                    radius: width / 2
                                    readonly property bool canUse: root.phoneService && root.phoneService.canRing

                                    color: ringMA.containsMouse && canUse ? Qt.rgba(root.walColor2.r, root.walColor2.g, root.walColor2.b, 0.15) : Qt.rgba(root.walColor0.r, root.walColor0.g, root.walColor0.b, 0.5)
                                    border.color: ringMA.containsMouse && canUse ? root.walColor2 : Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.22)
                                    border.width: 1
                                    opacity: canUse ? 1.0 : 0.35

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.phoneTarget
                                        color: ringBtn.canUse ? root.walForeground : root.walColor8
                                        font.pixelSize: Typography.sizeBodyLarge
                                        font.family: Typography.defaultFamily
                                    }

                                    MouseArea {
                                        id: ringMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: ringBtn.canUse ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                        onClicked: {
                                            if (ringBtn.canUse && root.phoneService) {
                                                root.phoneService.ringPhone()
                                            }
                                        }
                                    }

                                    // Simple custom tooltip on hover
                                    Rectangle {
                                        id: ringTip
                                        visible: ringMA.containsMouse
                                        z: 10
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: 8
                                        anchors.right: parent.right
                                        width: ringTipText.implicitWidth + 14
                                        height: ringTipText.implicitHeight + 8
                                        radius: Radius.small
                                        color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.95)
                                        border.color: Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.3)
                                        border.width: 1

                                        Text {
                                            id: ringTipText
                                            anchors.centerIn: parent
                                            text: ringBtn.canUse ? I18n.s.cd_ring_btn : I18n.s.cd_ring_disabled
                                            color: root.walForeground
                                            font.pixelSize: Typography.sizeTiny
                                            font.family: Typography.defaultFamily
                                        }
                                    }
                                }
                            }
                        }

                        // Body Row: Phone Mockup (Left) + 4 Stats (Right)
                        Row {
                            width: parent.width
                            spacing: Math.round(28 * UIScale.scale)

                            // Phone Mockup (Left)
                            Rectangle {
                                width: Math.round(112 * UIScale.scale)
                                height: Math.round(195 * UIScale.scale)
                                radius: 22
                                color: Qt.rgba(0, 0, 0, 0.45)
                                border.color: Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.28)
                                border.width: 2.5

                                // Screen area
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: 18
                                    color: (root.phoneService && root.phoneService.connected) ? Qt.rgba(root.walColor0.r, root.walColor0.g, root.walColor0.b, 0.65) : Qt.rgba(0, 0, 0, 0.6)

                                    // Top camera punch-hole
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 6
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: "#050505"
                                        border.color: Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.2)
                                        border.width: 1
                                    }

                                    // Ambient screen content when connected
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        opacity: (root.phoneService && root.phoneService.connected) ? 0.85 : 0.2

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Icons.phone
                                            color: (root.phoneService && root.phoneService.connected) ? root.walColor2 : root.walColor8
                                            font.pixelSize: Typography.sizeTitleMedium
                                            font.family: Typography.defaultFamily
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Qt.formatDateTime(new Date(), "hh:mm")
                                            color: root.walForeground
                                            font.pixelSize: Typography.sizeBodySmall
                                            font.bold: true
                                            font.family: Typography.defaultFamily
                                        }
                                    }

                                    // Chin gesture navigation bar
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 8
                                        width: 44
                                        height: 4
                                        radius: 2
                                        color: Qt.rgba(root.walForeground.r, root.walForeground.g, root.walForeground.b, 0.35)
                                    }
                                }
                            }

                            // 4 Status Items (Right)
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Math.round(13 * UIScale.scale)
                                width: parent.width - Math.round(140 * UIScale.scale)

                                // 1. Battery
                                Row {
                                    spacing: 14
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                    Item {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 28
                                        height: 14

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 22
                                            height: 12
                                            radius: 3
                                            color: "transparent"
                                            border.color: (root.phoneService && root.phoneService.connected) ? root.walForeground : root.walColor8
                                            border.width: 1.5

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                anchors.margins: 2
                                                width: Math.max(2, (parent.width - 4) * Math.min(1.0, Math.max(0.08, ((root.phoneService && root.phoneService.batteryLevel >= 0) ? root.phoneService.batteryLevel : 0) / 100.0)))
                                                radius: 1.5
                                                color: (root.phoneService && root.phoneService.batteryLevel <= 15) ? "#f38ba8" : root.walColor2
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 22
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 2.5
                                            height: 5
                                            radius: 1
                                            color: (root.phoneService && root.phoneService.connected) ? root.walForeground : root.walColor8
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            text: I18n.s.cd_battery
                                            color: root.walColor8
                                            font.pixelSize: Typography.sizeTiny
                                            font.family: Typography.defaultFamily
                                        }

                                        Text {
                                            text: {
                                                if (!root.phoneService || root.phoneService.batteryLevel < 0) return "--"
                                                var b = root.phoneService.batteryLevel + "%"
                                                if (root.phoneService.isCharging) b += " · " + I18n.s.cd_charging
                                                return b
                                            }
                                            color: root.walForeground
                                            font.pixelSize: Typography.sizeBodyLarge
                                            font.bold: true
                                            font.family: Typography.defaultFamily
                                        }
                                    }
                                }

                                // 2. Network
                                Row {
                                    spacing: 14
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (root.phoneService && root.phoneService.networkType === "5G") ? "5G" : "4G"
                                        color: (root.phoneService && root.phoneService.connected) ? root.walColor2 : root.walColor8
                                        font.pixelSize: Typography.sizeBodyLarge
                                        font.bold: true
                                        font.family: Typography.defaultFamily
                                        width: 28
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            text: I18n.s.cd_network
                                            color: root.walColor8
                                            font.pixelSize: Typography.sizeTiny
                                            font.family: Typography.defaultFamily
                                        }

                                        Text {
                                            text: (root.phoneService && root.phoneService.connected) ? root.phoneService.networkType : "--"
                                            color: root.walForeground
                                            font.pixelSize: Typography.sizeBodyLarge
                                            font.bold: true
                                            font.family: Typography.defaultFamily
                                        }
                                    }
                                }

                                // 3. Signal Strength
                                Row {
                                    spacing: 14
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                    Item {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 28
                                        height: 14

                                        Row {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            spacing: 3

                                            Repeater {
                                                model: 4
                                                Rectangle {
                                                    width: 3.5
                                                    height: 4 + (index * 3)
                                                    radius: 1.5
                                                    anchors.bottom: parent.bottom
                                                    color: (root.phoneService && root.phoneService.connected && (root.phoneService.signalLevel > index || (root.phoneService.signalLevel === 0 && index === 0)))
                                                           ? root.walColor2
                                                           : Qt.rgba(root.walColor8.r, root.walColor8.g, root.walColor8.b, 0.25)
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            text: I18n.s.cd_signal
                                            color: root.walColor8
                                            font.pixelSize: Typography.sizeTiny
                                            font.family: Typography.defaultFamily
                                        }

                                        Text {
                                            text: (root.phoneService && root.phoneService.connected) ? root.phoneService.signalStrength : "--"
                                            color: root.walForeground
                                            font.pixelSize: Typography.sizeBodyLarge
                                            font.bold: true
                                            font.family: Typography.defaultFamily
                                        }
                                    }
                                }

                                // 4. Notifications
                                Row {
                                    spacing: 14
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Icons.phoneMessage
                                        color: (root.phoneService && root.phoneService.connected && root.phoneService.notificationsCount > 0) ? root.walColor2 : root.walForeground
                                        font.pixelSize: Typography.sizeTitleMedium
                                        font.family: Typography.defaultFamily
                                        width: 28
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            text: I18n.s.cd_notifications
                                            color: root.walColor8
                                            font.pixelSize: Typography.sizeTiny
                                            font.family: Typography.defaultFamily
                                        }

                                        Text {
                                            text: (root.phoneService && root.phoneService.connected) ? root.phoneService.notificationsCount.toString() : "--"
                                            color: root.walForeground
                                            font.pixelSize: Typography.sizeBodyLarge
                                            font.bold: true
                                            font.family: Typography.defaultFamily
                                        }
                                    }
                                }
                            }
                        }

                        // Informational footer if not fully authorized or disconnected
                        Rectangle {
                            visible: !root.phoneService || !root.phoneService.connected || !root.phoneService.canScrcpy
                            width: parent.width
                            implicitHeight: footerText.implicitHeight + 14
                            radius: Radius.small
                            color: Qt.rgba(0, 0, 0, 0.2)
                            border.color: Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.15)
                            border.width: 1

                            Text {
                                id: footerText
                                anchors.centerIn: parent
                                width: parent.width - 20
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                text: {
                                    if (!root.phoneService || !root.phoneService.hasDevice) {
                                        return I18n.s.cd_no_device_sub
                                    }
                                    if (!root.phoneService.canScrcpy) {
                                        return I18n.s.cd_scrcpy_disabled
                                    }
                                    return ""
                                }
                                color: root.walColor8
                                font.pixelSize: Typography.sizeTiny
                                font.family: Typography.defaultFamily
                            }
                        }
                    }
                }
            }
        }
    }
}
