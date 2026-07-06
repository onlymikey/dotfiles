import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"

PanelWindow {
    id: btPanel
    visible: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: 40; right: root.btVisible ? 6 : -350 }
    implicitHeight: 460
    implicitWidth: 320
    color: "transparent"

    // Important: when "closed", don't participate in focus at all
    focusable: true
    WlrLayershell.keyboardFocus: root.btVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Behavior on margins.right { NumberAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }

    Connections {
        target: root
        function onBtVisibleChanged() {
            if (root.btVisible) {
                focusTimer.start()
            }
        }
    }
    Timer {
        id: focusTimer
        interval: 50
        repeat: false

        onTriggered: {
            btFocusAnchor.forceActiveFocus()
        }
    }

    FocusScope {
        id: btFocusScope
        anchors.fill: parent

        // Tie logical focus + input participation to visibility flag
        focus: root.btVisible
        enabled: root.btVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
            root.closeAllPanels()
            event.accepted = true
        }
        }

        // Always-focusable anchor (so we never end up with "no activeFocusItem")
        Item {
            id: btFocusAnchor
            focus: true
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.7)
            radius: Radius.panel

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: Spacing.md

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: {
                            var dev = root.bluetoothService.primaryConnectedAudioDevice
                            return dev ? dev.icon : Icons.bluetoothEnabled
                        }
                        color: root.walColor5
                        font.pixelSize: Typography.sizeHeadingSmall
                        font.family: Typography.defaultFamily
                    }
                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true
                        Text {
                            text: {
                                var dev = root.bluetoothService.primaryConnectedAudioDevice
                                return dev ? dev.name : "Bluetooth"
                            }
                            color: root.walColor5
                            font.pixelSize: Typography.sizeBodyLarge
                            font.bold: true
                            font.family: Typography.defaultFamily
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: root.bluetoothService.primaryConnectedAudioDevice !== null
                            text: {
                                var dev = root.bluetoothService.primaryConnectedAudioDevice
                                if (!dev) return ""
                                var t = "Connected"
                                if (dev.battery !== null) {
                                    t += Icons.separatorDot + dev.battery + "%"
                                }
                                return t
                            }
                            color: root.walColor8
                            font.pixelSize: Typography.sizeCaption
                            font.family: Typography.defaultFamily
                        }
                    }
                    Rectangle {
                        width: 44
                        height: 24
                        radius: Radius.large
                        color: root.btEnabled ? root.walColor5 : Qt.rgba(0.3, 0.3, 0.3, 0.5)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            width: 20
                            height: 20
                            radius: Radius.medium
                            y: 2
                            x: root.btEnabled ? 22 : 2
                            color: root.walBackground
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.btEnabled)
                                    root.bluetoothService.powerOff()
                                else
                                    root.bluetoothService.powerOn()
                            }
                        }
                    }
                }

                Text {
                    text: "Paired Devices"
                    color: root.walColor8
                    font.pixelSize: Typography.sizeBodySmall
                    font.family: Typography.defaultFamily
                    visible: root.btEnabled
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 180
                    color: Qt.rgba(0, 0, 0, 0.3)
                    radius: Radius.large
                    clip: true
                    visible: root.btEnabled
                    ListView {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: Spacing.xs
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.btPairedDevices
                        delegate: Rectangle {
                            width: parent ? parent.width : 0
                            height: 48
                            radius: Radius.medium
                            color: btPairedMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10
                                Text {
                                    text: modelData.icon
                                    color: modelData.connected ? root.walColor2 : root.walColor8
                                    font.pixelSize: Typography.sizeTitleMedium
                                    font.family: Typography.defaultFamily
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: modelData.name
                                        color: modelData.connected ? root.walColor2 : root.walForeground
                                        font.pixelSize: Typography.sizeNormal
                                        font.bold: modelData.connected
                                        font.family: Typography.defaultFamily
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: {
                                            if (root.btConnectingMAC === modelData.mac) return "Connecting..."
                                            if (modelData.connected) {
                                                var t = "Connected"
                                                if (modelData.battery !== null) {
                                                    t += Icons.separatorDot + modelData.battery + "%"
                                                }
                                                return t
                                            }
                                            return "Paired"
                                        }
                                        color: root.walColor8
                                        font.pixelSize: Typography.sizeCaption
                                        font.family: Typography.defaultFamily
                                    }
                                }
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: Radius.mediumSmall
                                    color: btConnBtnMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.connected ? Icons.close : Icons.add
                                        color: modelData.connected ? root.walColor1 : root.walColor5
                                        font.pixelSize: Typography.sizeNormal
                                        font.family: Typography.defaultFamily
                                    }
                                    MouseArea {
                                        id: btConnBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.connected)
                                                root.disconnectBt(modelData.mac)
                                            else
                                                root.connectBt(modelData.mac)
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: Radius.mediumSmall
                                    color: btForgetMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.trash
                                        color: root.walColor8
                                        font.pixelSize: Typography.sizeNormal
                                        font.family: Typography.defaultFamily
                                    }
                                    MouseArea {
                                        id: btForgetMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.forgetBt(modelData.mac)
                                    }
                                }
                            }
                            MouseArea {
                                id: btPairedMa
                                anchors.fill: parent
                                hoverEnabled: true
                                z: -1
                                onClicked: {
                                    if (modelData.connected)
                                        root.disconnectBt(modelData.mac)
                                    else
                                        root.connectBt(modelData.mac)
                                }
                            }
                        }
                        ScrollBar.vertical: ScrollBar { active: true; width: 4 }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.btPairedDevices.length === 0
                        text: "No paired devices"
                        color: root.walColor8
                        font.pixelSize: Typography.sizeNormal
                        font.family: Typography.defaultFamily
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.btEnabled
                    Text {
                        text: "Available Devices"
                        color: root.walColor8
                        font.pixelSize: Typography.sizeBodySmall
                        font.family: Typography.defaultFamily
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 60
                        height: 24
                        radius: Radius.small
                        color: btScanBtnMa.containsMouse ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.2) : Qt.rgba(0, 0, 0, 0.3)
                        Text {
                            anchors.centerIn: parent
                            text: root.btScanning ? "Scanning" : "Scan"
                            color: root.walColor5
                            font.pixelSize: Typography.sizeSmall
                            font.family: Typography.defaultFamily
                        }
                        MouseArea {
                            id: btScanBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.btScanning) {
                                    root.bluetoothService.startDiscovery()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Qt.rgba(0, 0, 0, 0.3)
                    radius: Radius.large
                    clip: true
                    visible: root.btEnabled
                    ListView {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: Spacing.xs
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.btAvailableDevices
                        delegate: Rectangle {
                            width: parent ? parent.width : 0
                            height: 44
                            radius: Radius.medium
                            color: btAvailMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10
                                Text {
                                    text: modelData.icon
                                    color: root.walColor8
                                    font.pixelSize: Typography.sizeTitleSmall
                                    font.family: Typography.defaultFamily
                                }
                                Text {
                                    text: modelData.name
                                    color: root.walForeground
                                    font.pixelSize: Typography.sizeNormal
                                    font.family: Typography.defaultFamily
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: modelData.signalStrength !== ""
                                    text: modelData.signalStrength
                                    color: root.walColor8
                                    font.pixelSize: Typography.sizeSmall
                                    font.family: Typography.defaultFamily
                                }
                                Text {
                                    visible: root.btConnectingMAC === modelData.mac
                                    text: "..."
                                    color: root.walColor8
                                    font.pixelSize: Typography.sizeNormal
                                    font.family: Typography.defaultFamily
                                }
                            }
                            MouseArea {
                                id: btAvailMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pairBt(modelData.mac)
                            }
                        }
                        ScrollBar.vertical: ScrollBar { active: true; width: 4 }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.btAvailableDevices.length === 0 && !root.btScanning
                        text: "Press Scan to find devices"
                        color: root.walColor8
                        font.pixelSize: Typography.sizeBodySmall
                        font.family: Typography.defaultFamily
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.btScanning
                        text: "Scanning..."
                        color: root.walColor8
                        font.pixelSize: Typography.sizeBodySmall
                        font.family: Typography.defaultFamily
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !root.btEnabled
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "Bluetooth is off"
                        color: root.walColor8
                        font.pixelSize: Typography.sizeBodyMedium
                        font.family: Typography.defaultFamily
                    }
                }
            }
        }
    }
}