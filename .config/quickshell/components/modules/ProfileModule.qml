import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../../theme"
import "../"

DashboardModule {
    id: profileModule
    displayName: "Profile"
    available: true
    implicitHeight: pfpPickerOpen ? 280 : 100

    property bool pfpPickerOpen: false
    property var pfpFiles: []

    Behavior on implicitHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Item {
                id: pfpContainer
                width: 74
                height: 74

                Rectangle {
                    anchors.fill: parent
                    radius: 37
                    color: "transparent"
                    border.width: 3
                    border.color: root.walColor5
                }

                Image {
                    id: pfpImage
                    anchors.centerIn: parent
                    width: 68
                    height: 68
                    source: Resources.defaultPfp
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    cache: false
                    sourceSize.width: 256
                    sourceSize.height: 256
                    visible: false

                    property int reloadTrigger: 0

                    function reload() {
                        reloadTrigger++
                        source = ""
                        source = Resources.defaultPfp + "?" + reloadTrigger
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 68
                    height: 68
                    radius: 34
                    visible: false
                    id: pfpMask
                }

                OpacityMask {
                    anchors.centerIn: parent
                    width: 68
                    height: 68
                    source: pfpImage
                    maskSource: pfpMask
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 22
                    height: 22
                    radius: 11
                    color: root.walColor5
                    border.width: 2
                    border.color: root.walBackground

                    Text {
                        anchors.centerIn: parent
                        text: Icons.profileEdit
                        color: root.walBackground
                        font.pixelSize: Typography.sizeNormal
                        font.family: Typography.defaultFamily
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        pfpPickerOpen = !pfpPickerOpen
                        if (pfpPickerOpen) {
                            pfpFiles = []
                            pfpListProc.running = true
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    text: Quickshell.env("USER")
                    color: root.walColor5
                    font.pixelSize: Typography.sizeHeadingLarge
                    font.bold: true
                    font.family: Typography.defaultFamily
                }

                Text {
                    id: uptimeText
                    text: "up ..."
                    color: root.walForeground
                    font.pixelSize: Typography.sizeNormal
                    font.family: Typography.defaultFamily
                }
            }

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Radius.mediumSmall
                color: setBtnHover.containsMouse ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.25) : Qt.rgba(0, 0, 0, 0.25)
                border.width: 1
                border.color: setBtnHover.containsMouse ? root.walColor5 : Qt.rgba(1, 1, 1, 0.08)

                Text {
                    anchors.centerIn: parent
                    text: Icons.settings
                    color: setBtnHover.containsMouse ? root.walColor5 : root.walColor8
                    font.pixelSize: Typography.sizeBodyLarge
                    font.family: Typography.defaultFamily
                }

                MouseArea {
                    id: setBtnHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.panelManager.open("settings")
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.3)
            radius: Radius.medium
            visible: pfpPickerOpen

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: Spacing.sm

                Text {
                    text: "Choose Avatar"
                    color: root.walColor5
                    font.pixelSize: Typography.sizeNormal
                    font.bold: true
                    font.family: Typography.defaultFamily
                    Layout.alignment: Qt.AlignHCenter
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: pfpGrid.height
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    GridLayout {
                        id: pfpGrid
                        width: parent.width
                        columns: 6
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: pfpFiles

                            Item {
                                width: 48
                                height: 48
                                Layout.alignment: Qt.AlignHCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 24
                                    color: "transparent"
                                    border.width: 2
                                    border.color: thumbMa.containsMouse ? root.walColor13 : root.walColor5
                                    Behavior on border.color { ColorAnimation { duration: Animations.fast } }
                                }

                                Image {
                                    id: thumbImg
                                    anchors.centerIn: parent
                                    width: 44
                                    height: 44
                                    source: "file://" + modelData
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    sourceSize.width: 128
                                    sourceSize.height: 128
                                    visible: false
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 44
                                    height: 44
                                    radius: 22
                                    visible: false
                                    id: thumbMask
                                }

                                OpacityMask {
                                    anchors.centerIn: parent
                                    width: 44
                                    height: 44
                                    source: thumbImg
                                    maskSource: thumbMask
                                }

                                MouseArea {
                                    id: thumbMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        setPfpProc.selFile = modelData
                                        setPfpProc.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: pfpListProc
        command: ["bash", "-c", "find '" + Resources.pfpsPath + "' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.gif' \\) ! -name 'pfp.jpg' | sort"]
        stdout: SplitParser {
            onRead: data => {
                var file = data.trim()
                if (file.length > 0) {
                    var current = profileModule.pfpFiles.slice()
                    current.push(file)
                    profileModule.pfpFiles = current
                }
            }
        }
    }

    Process {
        id: setPfpProc
        property string selFile: ""
        command: ["bash", "-c", "cp '" + selFile + "' '" + Resources.pfpsPath + "/pfp.jpg'"]
        onExited: {
            pfpImage.reload()
            pfpPickerOpen = false
        }
    }

    Process {
        id: uptimeProc
        command: ["bash", "-c", "uptime -p | sed 's/up //'"]
        stdout: SplitParser {
            onRead: data => {
                uptimeText.text = "up " + data.trim()
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!uptimeProc.running) uptimeProc.running = true
        }
    }
}
