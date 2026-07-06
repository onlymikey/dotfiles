import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"

PanelWindow {
    id: notifPanel
    visible: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: 40; right: root.notificationsVisible ? 6 : -350 }
    implicitHeight: 660
    implicitWidth: 320
    color: "transparent"

    focusable: true
    WlrLayershell.keyboardFocus: root.notificationsVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Behavior on margins.right { NumberAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }

    Connections {
        target: root
        function onNotificationsVisibleChanged() {
            if (root.notificationsVisible) {
                Qt.callLater(() => notifFocusAnchor.forceActiveFocus())
                root.notificationService.markAllAsRead()
            }
        }
    }

    // Relative time formatting function ( MVC: UI presents formatted state )
    function getRelativeTime(timeRaw) {
        if (!timeRaw) return ""
        var diffMs = new Date().getTime() - timeRaw
        var diffMins = Math.floor(diffMs / 60000)
        if (diffMins < 1) return "Now"
        if (diffMins < 60) return diffMins + " min ago"
        var diffHours = Math.floor(diffMins / 60)
        if (diffHours < 24) return diffHours + " hr ago"
        return "Yesterday"
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
            radius: Radius.panel

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: Spacing.md

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: root.notificationService.dnd ? Icons.notificationDnd : Icons.notificationActive
                        color: root.walColor5
                        font.pixelSize: Typography.sizeHeadingSmall
                        font.family: Typography.defaultFamily
                    }
                    Text {
                        text: "Notifications"
                        color: root.walColor5
                        font.pixelSize: Typography.sizeTitleSmall
                        font.bold: true
                        font.family: Typography.defaultFamily
                    }

                    Rectangle {
                        visible: root.notificationService.unreadCount > 0
                        height: 16
                        width: unreadText.implicitWidth + 10
                        radius: Radius.mediumSmall
                        color: root.walColor2

                        Text {
                            id: unreadText
                            anchors.centerIn: parent
                            text: root.notificationService.unreadCount.toString()
                            color: root.walBackground
                            font.pixelSize: Typography.sizeTiny
                            font.bold: true
                            font.family: Typography.defaultFamily
                        }
                    }
                    
                    Item { Layout.fillWidth: true }

                    // Do Not Disturb switch
                    RowLayout {
                        spacing: 6
                        Rectangle {
                            width: 28
                            height: 16
                            radius: Radius.mediumSmall
                            color: root.notificationService.dnd ? root.walColor2 : Qt.rgba(0.3, 0.3, 0.3, 0.5)
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                            Rectangle {
                                width: 12
                                height: 12
                                radius: Radius.small
                                y: 2
                                x: root.notificationService.dnd ? 14 : 2
                                color: root.walBackground
                                Behavior on x { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }
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
                            font.pixelSize: Typography.sizeTiny
                            font.family: Typography.defaultFamily
                        }
                    }

                    // Clear All button
                    Rectangle {
                        width: 24
                        height: 24
                        radius: Radius.small
                        color: clearAllMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: Icons.notificationCenterHeader
                            color: root.walColor1
                            font.pixelSize: Typography.sizeBodyLarge
                            font.family: Typography.defaultFamily
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

                // Empty State (Matches the design style)
                ColumnLayout {
                    visible: root.notificationService.history.count === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Spacing.xs
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.notificationService.dnd ? Icons.notificationDnd : Icons.notificationActive
                        font.family: Typography.defaultFamily
                        font.pixelSize: Typography.sizeHuge
                        color: root.walColor8
                        opacity: 0.3
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No notifications"
                        font.family: Typography.defaultFamily
                        font.pixelSize: Typography.sizeBodyLarge
                        font.bold: true
                        color: root.walForeground
                        opacity: 0.9
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "You're all caught up."
                        font.family: Typography.defaultFamily
                        font.pixelSize: Typography.sizeCaption
                        color: root.walColor8
                        opacity: 0.7
                    }
                }

                // Grouped Notifications List
                ListView {
                    visible: root.notificationService.history.count > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: root.notificationService.history
                    spacing: Spacing.sm
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: groupCard
                        width: parent.width
                        height: groupLayout.implicitHeight + 16
                        radius: Radius.large
                        color: Qt.rgba(0, 0, 0, 0.15)
                        border.color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1

                        ColumnLayout {
                            id: groupLayout
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: Spacing.xs

                            // Group Header (toggles expand/collapse)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Spacing.sm

                                MouseArea {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: {
                                        root.notificationService.history.setProperty(index, "expanded", !model.expanded)
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: Spacing.sm

                                        // Expand/Collapse Chevron
                                        Text {
                                            text: model.expanded ? "" : "" // FontAwesome chevrons
                                            font.family: Typography.defaultFamily
                                            font.pixelSize: Typography.sizeBodyMedium
                                            color: root.walColor8
                                            Behavior on text { SequentialAnimation { NumberAnimation { duration: 100 } } }
                                        }

                                        // App Icon
                                        Text {
                                            text: model.appIcon ? model.appIcon : Icons.notificationDefaultApp
                                            font.family: Typography.defaultFamily
                                            font.pixelSize: Typography.sizeNormal
                                            color: root.walColor2
                                        }

                                        // App Name
                                        Text {
                                            text: model.appName
                                            font.family: Typography.defaultFamily
                                            font.pixelSize: Typography.sizeBodySmall
                                            font.bold: true
                                            color: root.walColor5
                                            elide: Text.ElideRight
                                        }

                                        // Count Badge
                                        Rectangle {
                                            height: 16
                                            width: countText.implicitWidth + 10
                                            radius: Radius.small
                                            color: Qt.rgba(1, 1, 1, 0.1)

                                            Text {
                                                id: countText
                                                anchors.centerIn: parent
                                                text: model.count.toString()
                                                color: root.walColor8
                                                font.pixelSize: Typography.sizeTiny
                                                font.bold: true
                                                font.family: Typography.defaultFamily
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        // Latest relative timestamp when collapsed
                                        Text {
                                            visible: !model.expanded
                                            text: getRelativeTime(model.latestTimeRaw)
                                            font.family: Typography.defaultFamily
                                            font.pixelSize: Typography.sizeTiny
                                            color: root.walColor8
                                        }
                                    }
                                }

                                // Clear entire group button
                                MouseArea {
                                    width: 24
                                    height: 24
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.notificationService.clearGroup(model.appName)

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.trash
                                        font.family: Typography.defaultFamily
                                        font.pixelSize: Typography.sizeBodySmall
                                        color: root.walColor1
                                    }
                                }
                            }

                            // Nested Notifications Container (Smooth collapse/expand transition)
                            Column {
                                id: nestedColumn
                                Layout.fillWidth: true
                                spacing: Spacing.sm
                                clip: true

                                height: model.expanded ? implicitHeight : 0
                                opacity: model.expanded ? 1.0 : 0.0

                                Behavior on height { NumberAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: Animations.normal } }

                                Repeater {
                                    model: model.notifications

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: itemLayout.implicitHeight + 16
                                        radius: Radius.medium
                                        color: modelData.unread ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0.25)
                                        border.color: modelData.unread ? root.walColor5 : "transparent"
                                        border.width: 1

                                        property int notifId: modelData.id
                                        property bool hasDefaultAct: modelData.hasDefaultAction
                                        property var actionsList: modelData.notifActions

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
                                            anchors.margins: 8
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Spacing.sm

                                                // Relative Time
                                                Text {
                                                    text: getRelativeTime(modelData.timeRaw)
                                                    font.family: Typography.defaultFamily
                                                    font.pixelSize: Typography.sizeTiny
                                                    color: root.walColor8
                                                    Layout.fillWidth: true
                                                }

                                                // Unread Indicator
                                                Rectangle {
                                                    visible: modelData.unread
                                                    width: 6
                                                    height: 6
                                                    radius: 3
                                                    color: root.walColor2
                                                }

                                                // Dismiss individual notification button
                                                MouseArea {
                                                    width: 16
                                                    height: 16
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.notificationService.clearNotification(notifId)

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: Icons.close
                                                        font.family: Typography.defaultFamily
                                                        font.pixelSize: Typography.sizeTiny
                                                        color: root.walColor1
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 10

                                                Image {
                                                    visible: modelData.image !== ""
                                                    source: modelData.image || ""
                                                    Layout.preferredWidth: 32
                                                    Layout.preferredHeight: 32
                                                    fillMode: Image.PreserveAspectCrop
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: 0
                                                    spacing: 2

                                                    Text {
                                                        text: modelData.summary
                                                        font.family: Typography.defaultFamily
                                                        font.pixelSize: Typography.sizeBodySmall
                                                        font.bold: true
                                                        color: root.walForeground
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }

                                                    Text {
                                                        text: modelData.body
                                                        font.family: Typography.defaultFamily
                                                        font.pixelSize: Typography.sizeCaption
                                                        color: root.walColor8
                                                        wrapMode: Text.Wrap
                                                        maximumLineCount: 3
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                }
                                            }

                                            // Action Buttons (Reply / Open / Dismiss etc.)
                                            RowLayout {
                                                visible: actionsList !== undefined && actionsList !== null && actionsList.length > 0
                                                spacing: Spacing.sm
                                                Layout.fillWidth: true

                                                Repeater {
                                                    model: actionsList
                                                    delegate: Button {
                                                        text: modelData.text
                                                        flat: true
                                                        background: Rectangle {
                                                            color: parent.hovered ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
                                                            radius: Radius.small
                                                        }
                                                        contentItem: Text {
                                                            text: parent.text
                                                            font.family: Typography.defaultFamily
                                                            font.pixelSize: Typography.sizeCaption
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
            }
        }
    }
}
