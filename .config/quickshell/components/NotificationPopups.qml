import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"

PanelWindow {
    id: popupsWindow
    visible: true
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    anchors { top: true; right: true }
    margins { top: 46; right: 10 }

    color: "transparent"
    implicitWidth: 320
    implicitHeight: popupsColumn.implicitHeight

    ListModel {
        id: popupsModel
    }

    Connections {
        target: root.notificationService
        function onNotificationTriggered(id, appName, summary, body, appIcon, image, hasDefaultAction, notifActions) {
            var popupId = Date.now() + "_" + id
            popupsModel.insert(0, {
                popupId: popupId,
                notificationId: id,
                appName: appName,
                summary: summary,
                body: body,
                appIcon: appIcon,
                image: image,
                hasDefaultAction: hasDefaultAction,
                notifActions: notifActions
            })
        }
    }

    Column {
        id: popupsColumn
        width: parent.width
        spacing: 10

        move: Transition {
            NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: popupsModel

            delegate: Item {
                id: popupItem
                width: parent.width
                height: contentCard.height + 10

                property bool isRemoving: false
                property string popupIdVal: model ? model.popupId : ""
                property int notifId: model ? model.notificationId : 0
                property bool hasDefaultAct: model ? model.hasDefaultAction : false
                property var actionsList: (model && model.notifActions) ? model.notifActions : null

                Timer {
                    id: dismissTimer
                    interval: 5000
                    running: true
                    repeat: false
                    onTriggered: removePopup()
                }

                function removePopup() {
                    if (isRemoving) return
                    isRemoving = true
                    removeAnimation.start()
                }

                ParallelAnimation {
                    id: removeAnimation
                    NumberAnimation { target: contentCard; property: "opacity"; to: 0; duration: 200 }
                    NumberAnimation { target: contentCard; property: "x"; to: 350; duration: 250; easing.type: Easing.InCubic }
                    onFinished: {
                        for (var i = 0; i < popupsModel.count; i++) {
                            if (popupsModel.get(i).popupId === popupIdVal) {
                                popupsModel.remove(i)
                                break
                            }
                        }
                    }
                }

                Component.onCompleted: {
                    contentCard.opacity = 0
                    contentCard.x = 350
                    entryAnimation.start()
                }

                ParallelAnimation {
                    id: entryAnimation
                    NumberAnimation { target: contentCard; property: "opacity"; to: 1; duration: 200 }
                    NumberAnimation { target: contentCard; property: "x"; to: 0; duration: 250; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    id: contentCard
                    width: parent.width
                    height: popupLayout.implicitHeight + 20
                    radius: Radius.large
                    color: Qt.rgba(0.05, 0.05, 0.05, 0.95)
                    border.color: root.walColor8
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: hasDefaultAct ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) {
                                removePopup()
                            } else if (mouse.button === Qt.LeftButton && hasDefaultAct) {
                                root.notificationService.invokeAction(notifId, "default")
                                removePopup()
                            }
                        }
                    }

                    ColumnLayout {
                        id: popupLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: Spacing.sm

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Spacing.sm

                            Text {
                                text: model.appIcon ? model.appIcon : Icons.notificationDefaultApp
                                font.family: Typography.defaultFamily
                                font.pixelSize: Typography.sizeBodyLarge
                                color: root.walColor5
                            }

                            Text {
                                text: model.appName
                                font.family: Typography.defaultFamily
                                font.pixelSize: Typography.sizeSmall
                                font.bold: true
                                color: root.walColor2
                                Layout.fillWidth: true
                            }

                            MouseArea {
                                width: 16
                                height: 16
                                cursorShape: Qt.PointingHandCursor
                                onClicked: removePopup()
                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.close
                                    font.family: Typography.defaultFamily
                                    font.pixelSize: Typography.sizeSmall
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
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                fillMode: Image.PreserveAspectCrop
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: model.summary
                                    font.family: Typography.defaultFamily
                                    font.pixelSize: Typography.sizeBodySmall
                                    font.bold: true
                                    color: root.walForeground
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: model.body
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

                        RowLayout {
                            visible: actionsList !== null && actionsList.count > 0
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
                                        removePopup()
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
