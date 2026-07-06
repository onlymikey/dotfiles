import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../theme"

DashboardModule {
    id: audioModule
    displayName: "Audio & Brightness"
    available: true
    implicitHeight: mainColumn.implicitHeight + 30
    Behavior on implicitHeight { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }

    property int volVal: root.audioService.volume
    property int micVal: root.audioService.sourceVolume

    function getDeviceIcon(name, isInput) {
        var lower = name.toLowerCase()
        if (isInput) {
            if (lower.indexOf("usb") !== -1 || lower.indexOf("headset") !== -1 || lower.indexOf("headphone") !== -1) return Icons.audioDeviceMicrophone
            return Icons.audioDeviceInput
        } else {
            if (lower.indexOf("hdmi") !== -1 || lower.indexOf("displayport") !== -1 || lower.indexOf("dp") !== -1) return Icons.audioDeviceDisplay
            if (lower.indexOf("headset") !== -1 || lower.indexOf("headphone") !== -1 || lower.indexOf("auricular") !== -1 || lower.indexOf("bluetooth") !== -1) return Icons.audioDeviceHeadphones
            if (lower.indexOf("speaker") !== -1 || lower.indexOf("altavoz") !== -1) return Icons.audioDeviceSpeakers
            return Icons.audioVolumeHigh
        }
    }

    Column {
        id: mainColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 15
        spacing: 15

        // ================= SPEAKERS / OUTPUT SECTION =================

        /**
         * Speakers Volume Control Row
         */
        Row {
            width: parent.width
            spacing: 10

            Text {
                width: 25
                text: root.audioService.muted || audioModule.volVal == 0 ? Icons.audioMute : audioModule.volVal < 50 ? Icons.audioVolumeMedium : Icons.audioVolumeHigh
                color: root.walColor4
                font.pixelSize: Typography.sizeTitleMedium
                font.family: Typography.defaultFamily
                verticalAlignment: Text.AlignVCenter
                height: 24

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.audioService.toggleMute()
                }
            }

            Rectangle {
                id: volSlider
                width: parent.width - 75
                height: 8
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: Qt.rgba(0, 0, 0, 0.3)

                Rectangle {
                    width: parent.width * audioModule.volVal / 100
                    height: parent.height
                    radius: 4
                    color: root.walColor4
                    Behavior on width { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: function(mouse) {
                        var percent = Math.round((mouse.x / parent.width) * 100)
                        percent = Math.max(0, Math.min(100, percent))
                        root.audioService.setVolume(percent)
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            var percent = Math.round((mouse.x / parent.width) * 100)
                            percent = Math.max(0, Math.min(100, percent))
                            root.audioService.setVolume(percent)
                        }
                    }
                }
            }

            Text {
                width: 40
                text: audioModule.volVal + "%"
                color: root.walColor8
                font.pixelSize: Typography.sizeBodySmall
                font.family: Typography.defaultFamily
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                height: 24
            }
        }

        /**
         * Output Device Dropdown
         */
        Column {
            width: parent.width
            spacing: 5
            visible: root.audioService.outputs.length > 0

            Text {
                text: "Dispositivo de Salida"
                color: root.walColor8
                font.pixelSize: Typography.sizeBodySmall
                font.family: Typography.defaultFamily
            }

            Rectangle {
                id: outputDropdown
                width: parent.width
                height: expanded ? Math.min(180, 36 + (root.audioService.outputs.length * 30)) : 36
                radius: Radius.mediumSmall
                color: Qt.rgba(0, 0, 0, 0.3)
                clip: true
                border.color: expanded ? root.walColor4 : "transparent"
                border.width: 1
                Behavior on height { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }

                property bool expanded: false

                RowLayout {
                    id: outputHeader
                    width: parent.width
                    height: 36
                    anchors.top: parent.top
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        text: {
                            var def = root.audioService.defaultOutput
                            return def ? getDeviceIcon(def.name, false) + "  " + def.name : "Seleccionar dispositivo..."
                        }
                        color: root.walForeground
                        font.pixelSize: Typography.sizeBodySmall
                        font.family: Typography.defaultFamily
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.rightMargin: 12
                        text: outputDropdown.expanded ? "󰅃" : "󰅀"
                        color: root.walColor8
                        font.pixelSize: Typography.sizeNormal
                        font.family: Typography.defaultFamily
                    }
                }

                MouseArea {
                    anchors.fill: outputHeader
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        outputDropdown.expanded = !outputDropdown.expanded
                        if (outputDropdown.expanded) inputDropdown.expanded = false
                    }
                }

                ListView {
                    id: outputsList
                    anchors.top: outputHeader.bottom
                    anchors.bottom: parent.bottom
                    width: parent.width
                    model: root.audioService.outputs
                    interactive: contentHeight > height
                    clip: true

                    delegate: Rectangle {
                        width: parent.width
                        height: 30
                        color: outItemMA.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                text: getDeviceIcon(modelData.name, false) + "  " + modelData.name
                                color: modelData.isDefault ? root.walColor4 : root.walForeground
                                font.pixelSize: Typography.sizeBodySmall
                                font.bold: modelData.isDefault
                                font.family: Typography.defaultFamily
                                elide: Text.ElideRight
                            }

                            Text {
                                text: Icons.check
                                color: root.walColor4
                                font.pixelSize: Typography.sizeNormal
                                font.family: Typography.defaultFamily
                                visible: modelData.isDefault
                            }
                        }

                        MouseArea {
                            id: outItemMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.audioService.setOutput(modelData)
                                outputDropdown.expanded = false
                            }
                        }
                    }
                }
            }
        }

        // ================= MICROPHONE / INPUT SECTION =================

        /**
         * Microphone Volume Control Row
         */
        Row {
            width: parent.width
            spacing: 10

            Text {
                width: 25
                text: root.audioService.sourceMuted || audioModule.micVal == 0 ? "󰍭" : "󰍬"
                color: root.walColor13
                font.pixelSize: Typography.sizeTitleMedium
                font.family: Typography.defaultFamily
                verticalAlignment: Text.AlignVCenter
                height: 24

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.audioService.toggleSourceMute()
                }
            }

            Rectangle {
                id: micSlider
                width: parent.width - 75
                height: 8
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: Qt.rgba(0, 0, 0, 0.3)

                Rectangle {
                    width: parent.width * audioModule.micVal / 100
                    height: parent.height
                    radius: 4
                    color: root.walColor13
                    Behavior on width { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: function(mouse) {
                        var percent = Math.round((mouse.x / parent.width) * 100)
                        percent = Math.max(0, Math.min(100, percent))
                        root.audioService.setSourceVolume(percent)
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            var percent = Math.round((mouse.x / parent.width) * 100)
                            percent = Math.max(0, Math.min(100, percent))
                            root.audioService.setSourceVolume(percent)
                        }
                    }
                }
            }

            Text {
                width: 40
                text: audioModule.micVal + "%"
                color: root.walColor8
                font.pixelSize: Typography.sizeBodySmall
                font.family: Typography.defaultFamily
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                height: 24
            }
        }

        /**
         * Input Device Dropdown
         */
        Column {
            width: parent.width
            spacing: 5
            visible: root.audioService.inputs.length > 0

            Text {
                text: "Dispositivo de Entrada"
                color: root.walColor8
                font.pixelSize: Typography.sizeBodySmall
                font.family: Typography.defaultFamily
            }

            Rectangle {
                id: inputDropdown
                width: parent.width
                height: expanded ? Math.min(180, 36 + (root.audioService.inputs.length * 30)) : 36
                radius: Radius.mediumSmall
                color: Qt.rgba(0, 0, 0, 0.3)
                clip: true
                border.color: expanded ? root.walColor13 : "transparent"
                border.width: 1
                Behavior on height { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }

                property bool expanded: false

                RowLayout {
                    id: inputHeader
                    width: parent.width
                    height: 36
                    anchors.top: parent.top
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        text: {
                            var def = root.audioService.defaultInput
                            return def ? getDeviceIcon(def.name, true) + "  " + def.name : "Seleccionar dispositivo..."
                        }
                        color: root.walForeground
                        font.pixelSize: Typography.sizeBodySmall
                        font.family: Typography.defaultFamily
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.rightMargin: 12
                        text: inputDropdown.expanded ? "󰅃" : "󰅀"
                        color: root.walColor8
                        font.pixelSize: Typography.sizeNormal
                        font.family: Typography.defaultFamily
                    }
                }

                MouseArea {
                    anchors.fill: inputHeader
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        inputDropdown.expanded = !inputDropdown.expanded
                        if (inputDropdown.expanded) outputDropdown.expanded = false
                    }
                }

                ListView {
                    id: inputsList
                    anchors.top: inputHeader.bottom
                    anchors.bottom: parent.bottom
                    width: parent.width
                    model: root.audioService.inputs
                    interactive: contentHeight > height
                    clip: true

                    delegate: Rectangle {
                        width: parent.width
                        height: 30
                        color: inItemMA.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                text: getDeviceIcon(modelData.name, true) + "  " + modelData.name
                                color: modelData.isDefault ? root.walColor13 : root.walForeground
                                font.pixelSize: Typography.sizeBodySmall
                                font.bold: modelData.isDefault
                                font.family: Typography.defaultFamily
                                elide: Text.ElideRight
                            }

                            Text {
                                text: Icons.check
                                color: root.walColor13
                                font.pixelSize: Typography.sizeNormal
                                font.family: Typography.defaultFamily
                                visible: modelData.isDefault
                            }
                        }

                        MouseArea {
                            id: inItemMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.audioService.setInput(modelData)
                                inputDropdown.expanded = false
                            }
                        }
                    }
                }
            }
        }

        // ================= BRIGHTNESS SECTION =================

        /**
         * Brightness Control Section
         */
        Row {
            width: parent.width
            spacing: 10
            visible: root.brightnessService.supported

            Text {
                width: 25
                text: root.brightnessService.brightness < 30 ? "󰃞" : root.brightnessService.brightness < 70 ? "󰃟" : "󰃠"
                color: root.walColor13
                font.pixelSize: Typography.sizeTitleMedium
                font.family: Typography.defaultFamily
                verticalAlignment: Text.AlignVCenter
                height: 24
            }

            Rectangle {
                id: brightSlider
                width: parent.width - 75
                height: 8
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: Qt.rgba(0, 0, 0, 0.3)

                Rectangle {
                    width: parent.width * root.brightnessService.brightness / 100
                    height: parent.height
                    radius: 4
                    color: root.walColor13
                    Behavior on width { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: function(mouse) {
                        var percent = Math.round((mouse.x / parent.width) * 100)
                        percent = Math.max(1, Math.min(100, percent))
                        root.brightnessService.setBrightness(percent)
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            var percent = Math.round((mouse.x / parent.width) * 100)
                            percent = Math.max(1, Math.min(100, percent))
                            root.brightnessService.setBrightness(percent)
                        }
                    }
                }
            }

            Text {
                width: 40
                text: root.brightnessService.brightness + "%"
                color: root.walColor8
                font.pixelSize: Typography.sizeBodySmall
                font.family: Typography.defaultFamily
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                height: 24
            }
        }
    }


}
