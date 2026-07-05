import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: wifiPanel
    visible: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: 40; right: root.wifiVisible ? 6 : -350 }
    implicitHeight: 540
    implicitWidth: 320
    color: "transparent"

    focusable: true
    WlrLayershell.keyboardFocus: root.wifiVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Behavior on margins.right { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    property string wifiPasswordSSID: ""
    property bool showActiveDetails: false

    Connections {
        target: root
        function onWifiVisibleChanged() {
            if (root.wifiVisible) {
                Qt.callLater(() => {
                    if (wifiPasswordSSID !== "") wifiPassInput.forceActiveFocus()
                    else wifiFocusAnchor.forceActiveFocus()
                })
            } else {
                wifiPasswordSSID = ""
                wifiPassInput.text = ""
                showActiveDetails = false
            }
        }
    }

    FocusScope {
        id: wifiFocusScope
        anchors.fill: parent
        focus: root.wifiVisible
        enabled: root.wifiVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (wifiPasswordSSID !== "") {
                    wifiPasswordSSID = ""
                    wifiPassInput.text = ""
                    Qt.callLater(() => wifiFocusAnchor.forceActiveFocus())
                } else {
                    root.closeAllPanels()
                }
                event.accepted = true
            }
        }

        Item {
            id: wifiFocusAnchor
            focus: true
        }
        
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.7)
            radius: 20

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: root.networkService.airplaneMode ? "󰀝" : "󰤨"
                        color: root.walColor5
                        font.pixelSize: 22
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: root.networkService.airplaneMode ? "Airplane Mode" : "Network"
                        color: root.walColor5
                        font.pixelSize: 16
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 44
                        height: 24
                        radius: 12
                        color: root.wifiEnabled ? root.walColor5 : Qt.rgba(0.3, 0.3, 0.3, 0.5)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            y: 2
                            x: root.wifiEnabled ? 22 : 2
                            color: root.walBackground
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.networkService.toggleWifi(!root.wifiEnabled)
                        }
                    }
                }

                Item { Layout.preferredHeight: 4 } // Section spacer

                // Ethernet Devices Section
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: root.networkService.ethernetDevices.length > 0
                    
                    Text {
                        text: "Wired Connections"
                        color: root.walColor8
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    
                    Repeater {
                        model: root.networkService.ethernetDevices
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            radius: 12
                            color: Qt.rgba(0, 0, 0, 0.3)
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10
                                Text {
                                    text: "󰈀"
                                    color: modelData.connected ? root.walColor2 : root.walColor8
                                    font.pixelSize: 18
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: "Ethernet (" + modelData.interface + ")"
                                        color: modelData.connected ? root.walColor2 : root.walForeground
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                    Text {
                                        text: modelData.connected ? "Connected • " + modelData.speed : "Cable disconnected"
                                        color: root.walColor8
                                        font.pixelSize: 9
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }
                                Rectangle {
                                    width: 32
                                    height: 18
                                    radius: 9
                                    color: modelData.connected ? root.walColor2 : Qt.rgba(0.3, 0.3, 0.3, 0.5)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Rectangle {
                                        width: 14
                                        height: 14
                                        radius: 7
                                        y: 2
                                        x: modelData.connected ? 16 : 2
                                        color: root.walBackground
                                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.networkService.toggleEthernet(modelData.interface, !modelData.connected)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.preferredHeight: 4
                    visible: root.networkService.vpnConnections.length > 0
                }

                // VPN Connections Section
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: root.networkService.vpnConnections.length > 0
                    
                    Text {
                        text: "Virtual Private Networks"
                        color: root.walColor8
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    
                    Repeater {
                        model: root.networkService.vpnConnections
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: 10
                            color: Qt.rgba(0, 0, 0, 0.3)
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10
                                Text {
                                    text: "󰖂"
                                    color: modelData.connected ? root.walColor5 : root.walColor8
                                    font.pixelSize: 16
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: modelData.name
                                        color: modelData.connected ? root.walColor5 : root.walForeground
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.family: "JetBrainsMono Nerd Font"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: modelData.connected ? "Connected" : "Disconnected"
                                        color: root.walColor8
                                        font.pixelSize: 9
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.preferredHeight: 4
                    visible: root.networkService.connectedNetwork !== null
                }

                // Connected Network Card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: showActiveDetails ? 150 : 70
                    radius: 12
                    color: Qt.rgba(0, 0, 0, 0.3)
                    visible: root.networkService.connectedNetwork !== null
                    clip: true
                    
                    Behavior on implicitHeight {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 16
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                text: {
                                    var net = root.networkService.connectedNetwork
                                    if (!net) return "󰤟"
                                    return net.signal > 75 ? "󰤨" : net.signal > 50 ? "󰤥" : net.signal > 25 ? "󰤢" : "󰤟"
                                }
                                color: root.walColor2
                                font.pixelSize: 20
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                spacing: 1
                                Text {
                                    text: root.networkService.connectedNetwork ? root.networkService.connectedNetwork.ssid : ""
                                    color: root.walColor2
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: "JetBrainsMono Nerd Font"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: {
                                        var net = root.networkService.connectedNetwork
                                        if (!net) return ""
                                        var t = "Connected"
                                        if (net.frequency) t += " • " + net.frequency
                                        if (net.security) t += " • " + net.security
                                        if (net.ipv4) t += " • " + net.ipv4
                                        return t
                                    }
                                    color: root.walColor8
                                    font.pixelSize: 9
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                            }
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 8
                                color: wifiDiscMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: root.walColor1
                                    font.pixelSize: 12
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                MouseArea {
                                    id: wifiDiscMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.networkService.disconnectDevice()
                                }
                            }
                        }

                        // Switch & Details Link row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    width: 28
                                    height: 16
                                    radius: 8
                                    color: (root.networkService.connectedNetwork && root.networkService.connectedNetwork.autoconnect) ? root.walColor2 : Qt.rgba(0.3, 0.3, 0.3, 0.5)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Rectangle {
                                        width: 12
                                        height: 12
                                        radius: 6
                                        y: 2
                                        x: (root.networkService.connectedNetwork && root.networkService.connectedNetwork.autoconnect) ? 14 : 2
                                        color: root.walBackground
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var net = root.networkService.connectedNetwork
                                            if (net) {
                                                root.networkService.toggleAutoconnect(net.ssid, !net.autoconnect)
                                            }
                                        }
                                    }
                                }
                                Text {
                                    text: "Auto-connect"
                                    color: root.walColor8
                                    font.pixelSize: 8
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Text {
                                text: wifiPanel.showActiveDetails ? "less..." : "more..."
                                color: root.walColor5
                                font.pixelSize: 8
                                font.family: "JetBrainsMono Nerd Font"
                                font.underline: true
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wifiPanel.showActiveDetails = !wifiPanel.showActiveDetails
                                }
                            }
                        }

                        // Collapsible Details section
                        ColumnLayout {
                            visible: wifiPanel.showActiveDetails
                            Layout.fillWidth: true
                            spacing: 2
                            
                            Text {
                                text: "IPv4: " + (root.networkService.connectedNetwork && root.networkService.connectedNetwork.ipv4 ? root.networkService.connectedNetwork.ipv4 : "N/A")
                                color: root.walColor8
                                font.pixelSize: 8
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Text {
                                text: "IPv6: " + (root.networkService.connectedNetwork && root.networkService.connectedNetwork.ipv6 ? root.networkService.connectedNetwork.ipv6 : "N/A")
                                color: root.walColor8
                                font.pixelSize: 8
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Text {
                                text: "Gateway: " + (root.networkService.connectedNetwork && root.networkService.connectedNetwork.gateway ? root.networkService.connectedNetwork.gateway : "N/A")
                                color: root.walColor8
                                font.pixelSize: 8
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Text {
                                text: "DNS: " + (root.networkService.connectedNetwork && root.networkService.connectedNetwork.dns && root.networkService.connectedNetwork.dns.length > 0 ? root.networkService.connectedNetwork.dns.join(", ") : "N/A")
                                color: root.walColor8
                                font.pixelSize: 8
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Text {
                                text: "MAC: " + (root.networkService.connectedNetwork && root.networkService.connectedNetwork.mac ? root.networkService.connectedNetwork.mac : "N/A")
                                color: root.walColor8
                                font.pixelSize: 8
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }
                    }
                }

                // Password input dialog
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: Qt.rgba(0, 0, 0, 0.3)
                    visible: wifiPasswordSSID !== ""
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        Text {
                            text: "󰌾"
                            color: root.walColor8
                            font.pixelSize: 12
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        TextInput {
                            id: wifiPassInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: root.walForeground
                            font.pixelSize: 12
                            font.family: "JetBrainsMono Nerd Font"
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            clip: true
                            Text {
                                text: "Password for " + wifiPasswordSSID
                                color: root.walColor8
                                visible: !parent.text
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                font: parent.font
                            }
                            Keys.onReturnPressed: {
                                if (wifiPassInput.text.length > 0) {
                                    root.wifiConnecting = true
                                    root.networkService.connectDevice(wifiPasswordSSID, wifiPassInput.text)
                                    wifiPasswordSSID = ""
                                    wifiPassInput.text = ""
                                    wifiFocusAnchor.forceActiveFocus()
                                }
                            }
                            Keys.onEscapePressed: {
                                wifiPasswordSSID = ""
                                wifiPassInput.text = ""
                            }
                        }
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 6
                            color: root.walColor5
                            Text {
                                anchors.centerIn: parent
                                text: "→"
                                color: root.walBackground
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (wifiPassInput.text.length > 0) {
                                        root.wifiConnecting = true
                                        root.networkService.connectDevice(wifiPasswordSSID, wifiPassInput.text)
                                        wifiPasswordSSID = ""
                                        wifiPassInput.text = ""
                                        wifiFocusAnchor.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: 4 } // Section spacer

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.wifiEnabled
                    Text {
                        text: "Available Networks"
                        color: root.walColor8
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 6
                        color: wifiRefreshMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                        
                        Text {
                            id: wifiRefreshIcon
                            anchors.centerIn: parent
                            text: root.wifiScanning ? "󰑓" : "󰑐"
                            color: root.walColor8
                            font.pixelSize: 12
                            font.family: "JetBrainsMono Nerd Font"
                            transformOrigin: Item.Center
                            
                            RotationAnimation on rotation {
                                running: root.wifiScanning
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 1000
                            }
                        }
                        
                        MouseArea {
                            id: wifiRefreshMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.wifiScanning) root.networkService.scan()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Qt.rgba(0, 0, 0, 0.3)
                    radius: 12
                    clip: true
                    ListView {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.networkService.availableNetworks
                        delegate: Rectangle {
                            width: parent ? parent.width : 0
                            height: 44
                            radius: 10
                            color: wifiNetMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10
                                Text {
                                    text: modelData.signal > 75 ? "󰤨" : modelData.signal > 50 ? "󰤥" : modelData.signal > 25 ? "󰤢" : "󰤟"
                                    color: modelData.saved ? root.walColor2 : root.walColor5
                                    font.pixelSize: 16
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: modelData.ssid
                                        color: root.walForeground
                                        font.pixelSize: 12
                                        font.family: "JetBrainsMono Nerd Font"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: {
                                            var detail = ""
                                            if (modelData.saved) detail += "Saved • "
                                            detail += modelData.security + " • " + modelData.frequency + " • " + modelData.signal + "% (" + modelData.quality + ")"
                                            return detail
                                        }
                                        color: root.walColor8
                                        font.pixelSize: 9
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }
                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 6
                                    visible: modelData.saved
                                    color: forgetMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰆴"
                                        color: root.walColor8
                                        font.pixelSize: 12
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                    MouseArea {
                                        id: forgetMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.networkService.forgetDevice(modelData.ssid)
                                    }
                                }
                            }
                            MouseArea {
                                id: wifiNetMa
                                anchors.fill: parent
                                anchors.rightMargin: modelData.saved ? 34 : 0
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.saved) {
                                        root.wifiConnecting = true
                                        root.networkService.connectDevice(modelData.ssid, "")
                                    } else if (modelData.security !== "Open") {
                                        wifiPasswordSSID = modelData.ssid
                                        wifiPassInput.text = ""
                                        wifiPassInput.forceActiveFocus()
                                    } else {
                                        root.wifiConnecting = true
                                        root.networkService.connectDevice(modelData.ssid, "")
                                    }
                                }
                            }
                        }
                        ScrollBar.vertical: ScrollBar { active: true; width: 4 }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.networkService.availableNetworks.length === 0 && !root.wifiScanning
                        text: root.wifiEnabled ? "No networks found" : "Wi-Fi is off"
                        color: root.walColor8
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.wifiScanning
                        text: "Scanning..."
                        color: root.walColor8
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }
        }
    }
}