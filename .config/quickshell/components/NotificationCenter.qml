import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: notifPanel
    visible: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: 40; right: root.notificationsVisible ? 6 : -350 }
    implicitHeight: 540
    implicitWidth: 320
    color: "transparent"

    focusable: true
    WlrLayershell.keyboardFocus: root.notificationsVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Behavior on margins.right { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    Connections {
        target: root
        function onNotificationsVisibleChanged() {
            if (root.notificationsVisible) {
                Qt.callLater(() => notifFocusAnchor.forceActiveFocus())
                root.notificationService.markAllAsRead()
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.closeAllPanels()
                event.accepted = true
            }
        }

        Item {
            id: notifFocusAnchor
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

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: root.notificationService.dnd ? "󰂛" : "󰂚"
                        color: root.walColor5
                        font.pixelSize: 22
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: "Notifications"
                        color: root.walColor5
                        font.pixelSize: 16
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Rectangle {
                        visible: root.notificationService.unreadCount > 0
                        height: 16
                        width: unreadText.implicitWidth + 10
                        radius: 8
                        color: root.walColor2

                        Text {
                            id: unreadText
                            anchors.centerIn: parent
                            text: root.notificationService.unreadCount.toString()
                            color: root.walBackground
                            font.pixelSize: 8
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }
                    
                    Item { Layout.fillWidth: true }

                    // Do Not Disturb switch
                    RowLayout {
                        spacing: 6
                        Rectangle {
                            width: 28
                            height: 16
                            radius: 8
                            color: root.notificationService.dnd ? root.walColor2 : Qt.rgba(0.3, 0.3, 0.3, 0.5)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                y: 2
                                x: root.notificationService.dnd ? 14 : 2
                                color: root.walBackground
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.notificationService.toggleDnd()
                            }
                        }
                        Text {
                            text: "DND"
                            color: root.walColor8
                            font.pixelSize: 8
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }

                    // Clear All button
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 6
                        color: clearAllMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰎟"
                            color: root.walColor1
                            font.pixelSize: 14
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        
                        MouseArea {
                            id: clearAllMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.notificationService.clearAll()
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.walColor8
                    opacity: 0.3
                }

                // Empty State
                ColumnLayout {
                    visible: root.notificationService.history.count === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.notificationService.dnd ? "󰂛" : "󰂚"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 48
                        color: root.walColor8
                        opacity: 0.5
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No notifications"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: root.walColor8
                        opacity: 0.8
                    }
                }

                // Notifications List
                ListView {
                    visible: root.notificationService.history.count > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: root.notificationService.history
                    spacing: 8
                    clip: true

                    delegate: Rectangle {
                        width: parent.width
                        height: itemLayout.implicitHeight + 20
                        radius: 12
                        color: model.unread ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.2)
                        border.color: model.unread ? root.walColor5 : "transparent"
                        border.width: 1

                        property int notifId: model ? model.id : 0
                        property bool hasDefaultAct: model ? model.hasDefaultAction : false
                        property var actionsList: (model && model.notifActions) ? model.notifActions : null

                        MouseArea {
                            anchors.fill: parent
                            enabled: hasDefaultAct
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                root.notificationService.invokeAction(notifId, "default")
                                root.closeAllPanels()
                            }
                        }

                        ColumnLayout {
                            id: itemLayout
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: model.appIcon ? model.appIcon : "󰵅"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: root.walColor2
                                }

                                Text {
                                    text: model.appName
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: root.walColor5
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: model.timestamp
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                    color: root.walColor8
                                }

                                Rectangle {
                                    visible: model.unread
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: root.walColor2
                                }

                                MouseArea {
                                    width: 16
                                    height: 16
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.notificationService.clearNotification(model.id)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: root.walColor1
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Image {
                                    visible: model.image !== ""
                                    source: model.image || ""
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    fillMode: Image.PreserveAspectCrop
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 0
                                    spacing: 2

                                    Text {
                                        text: model.summary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: root.walForeground
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: model.body
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                        color: root.walColor8
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            RowLayout {
                                visible: actionsList !== null && actionsList.count > 0
                                spacing: 8
                                Layout.fillWidth: true

                                Repeater {
                                    model: actionsList
                                    delegate: Button {
                                        text: modelData.text
                                        flat: true
                                        background: Rectangle {
                                            color: parent.hovered ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
                                            radius: 6
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            color: root.walForeground
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                        onClicked: {
                                            root.notificationService.invokeAction(notifId, modelData.identifier)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
