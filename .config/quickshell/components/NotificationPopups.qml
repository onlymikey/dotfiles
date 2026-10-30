import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"

PanelWindow {
    id: popupsWindow
    screen: root.focusedScreen
    readonly property string screenName: popupsWindow.screen ? popupsWindow.screen.name : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "DP-3")
    readonly property var hyprMonitor: Hyprland.monitorFor(popupsWindow.screen)
    readonly property bool hasFullscreen: {
        if (root.fullscreenByMonitor && root.fullscreenByMonitor.hasOwnProperty(popupsWindow.screenName)) {
            return !!root.fullscreenByMonitor[popupsWindow.screenName]
        }
        return hyprMonitor && hyprMonitor.activeWorkspace ? hyprMonitor.activeWorkspace.hasFullscreen : false
    }
    visible: popupsModel.count > 0 && !popupsWindow.hasFullscreen
    exclusionMode: ExclusionMode.Ignore

    // Dynamically grab keyboard focus only when the user is typing a reply
    property int activeReplyCount: 0
    focusable: activeReplyCount > 0

    anchors { top: true; right: true }
    margins { top: 46; right: 10 }

    color: "transparent"
    implicitWidth: Math.round(330 * UIScale.scale)
    implicitHeight: popupsColumn.implicitHeight

    function resolveIconSource(iconVal) {
        if (!iconVal || iconVal.length <= 2) return ""
        if (iconVal.startsWith("file://") || iconVal.startsWith("image://") || iconVal.startsWith("http")) return iconVal
        if (iconVal.startsWith("/")) return "file://" + iconVal
        return "image://icon/" + iconVal
    }

    function parseActions(jsonStr) {
        if (!jsonStr || jsonStr === "") return []
        try {
            var parsed = JSON.parse(jsonStr)
            return Array.isArray(parsed) ? parsed : []
        } catch (e) {
            return []
        }
    }

    ListModel {
        id: popupsModel
    }

    Connections {
        target: root.notificationService
        function onNotificationTriggered(id, appName, summary, body, appIcon, image, hasDefaultAction, notifActions, hasInlineReply) {
            var cleanedApp = (appName || "Notification").trim() || "Notification"
            var groupKey = cleanedApp.toLowerCase()
            var actionsJson = JSON.stringify(notifActions || [])

            // Group active popups from the same application so rapid notifications don't flood the screen
            for (var i = 0; i < popupsModel.count; i++) {
                var existing = popupsModel.get(i)
                if (existing.groupKey === groupKey) {
                    var newCount = (existing.groupCount || 1) + 1
                    popupsModel.set(i, {
                        popupId: existing.popupId,
                        groupKey: groupKey,
                        groupCount: newCount,
                        notificationId: id,
                        appName: cleanedApp,
                        summary: summary || "",
                        body: body || "",
                        appIcon: appIcon || existing.appIcon || "",
                        image: image || "",
                        hasDefaultAction: Boolean(hasDefaultAction),
                        notifActionsJson: actionsJson,
                        hasInlineReply: Boolean(hasInlineReply),
                        refreshTick: (existing.refreshTick || 0) + 1
                    })
                    if (i > 0) {
                        popupsModel.move(i, 0, 1)
                    }
                    return
                }
            }

            var popupId = Date.now() + "_" + id
            popupsModel.insert(0, {
                popupId: popupId,
                groupKey: groupKey,
                groupCount: 1,
                notificationId: id,
                appName: cleanedApp,
                summary: summary || "",
                body: body || "",
                appIcon: appIcon || "",
                image: image || "",
                hasDefaultAction: Boolean(hasDefaultAction),
                notifActionsJson: actionsJson,
                hasInlineReply: Boolean(hasInlineReply),
                refreshTick: 0
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
                property var actionsList: popupsWindow.parseActions(model ? model.notifActionsJson : "[]")
                property string iconSourceUrl: popupsWindow.resolveIconSource(model ? model.appIcon : "")
                property int currentRefreshTick: model ? model.refreshTick : 0

                property bool hasInlineRep: model ? model.hasInlineReply : false
                property bool showingReplyInput: false

                onCurrentRefreshTickChanged: {
                    if (!showingReplyInput && !isRemoving) {
                        dismissTimer.restart()
                    }
                }

                onShowingReplyInputChanged: {
                    if (showingReplyInput) {
                        popupsWindow.activeReplyCount++
                    } else {
                        popupsWindow.activeReplyCount--
                    }
                }

                Component.onDestruction: {
                    if (showingReplyInput) {
                        popupsWindow.activeReplyCount--
                    }
                }

                Timer {
                    id: dismissTimer
                    interval: 5000
                    running: !popupItem.showingReplyInput
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
                                root.notificationService.clearNotification(notifId)
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

                            Item {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18

                                Image {
                                    id: popupAppImg
                                    anchors.fill: parent
                                    visible: popupItem.iconSourceUrl !== "" && status === Image.Ready
                                    source: popupItem.iconSourceUrl
                                    fillMode: Image.PreserveAspectFit
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !popupAppImg.visible
                                    text: (model.appIcon && model.appIcon.length <= 2) ? model.appIcon : Icons.notificationDefaultApp
                                    font.family: Typography.defaultFamily
                                    font.pixelSize: Typography.sizeBodyLarge
                                    color: root.walColor5
                                }
                            }

                            Text {
                                text: model.appName
                                font.family: Typography.defaultFamily
                                font.pixelSize: Typography.sizeSmall
                                font.bold: true
                                color: root.walColor2
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Grouped count badge when multiple notifications arrive from the same app
                            Rectangle {
                                visible: (model.groupCount || 1) > 1
                                height: 16
                                width: popupGroupCountText.implicitWidth + 10
                                radius: Radius.small
                                color: Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.2)

                                Text {
                                    id: popupGroupCountText
                                    anchors.centerIn: parent
                                    text: "+" + ((model.groupCount || 1) - 1) + " más"
                                    color: root.walColor5
                                    font.pixelSize: Typography.sizeTiny
                                    font.bold: true
                                    font.family: Typography.defaultFamily
                                }
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
                                visible: model.image !== "" && status === Image.Ready
                                source: popupsWindow.resolveIconSource(model.image)
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
                                    visible: model.body !== ""
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

                        // Action Buttons Row (Responder / Open / Dismiss etc.)
                        RowLayout {
                            visible: ((popupItem.actionsList && popupItem.actionsList.length > 0) || hasInlineRep) && !popupItem.showingReplyInput
                            spacing: Spacing.sm
                            Layout.fillWidth: true

                            Button {
                                visible: hasInlineRep
                                text: "Responder"
                                flat: true
                                background: Rectangle {
                                    color: parent.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                                    radius: Radius.small
                                }
                                contentItem: Text {
                                    text: parent.text
                                    font.family: Typography.defaultFamily
                                    font.pixelSize: Typography.sizeCaption
                                    font.bold: true
                                    color: root.walColor5
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                onClicked: {
                                    popupItem.showingReplyInput = true
                                }
                            }

                            Repeater {
                                model: popupItem.actionsList
                                delegate: Button {
                                    required property var modelData
                                    text: modelData.text || ""
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
                                        root.notificationService.invokeAction(popupItem.notifId, modelData.identifier)
                                        root.notificationService.clearNotification(popupItem.notifId)
                                        popupItem.removePopup()
                                    }
                                }
                            }
                        }

                        // Inline Reply Input Field
                        RowLayout {
                            visible: popupItem.showingReplyInput
                            spacing: Spacing.sm
                            Layout.fillWidth: true

                            TextField {
                                id: replyField
                                Layout.fillWidth: true
                                placeholderText: "Responder..."
                                placeholderTextColor: root.walColor8
                                color: root.walForeground
                                font.family: Typography.defaultFamily
                                font.pixelSize: Typography.sizeCaption
                                focus: popupItem.showingReplyInput
                                background: Rectangle {
                                    color: Qt.rgba(0, 0, 0, 0.25)
                                    border.color: replyField.activeFocus ? root.walColor5 : Qt.rgba(1, 1, 1, 0.05)
                                    border.width: 1
                                    radius: Radius.small
                                }
                                onAccepted: {
                                    if (text.trim() !== "") {
                                        root.notificationService.sendReply(popupItem.notifId, text)
                                        text = ""
                                        popupItem.removePopup()
                                    }
                                }
                            }

                            Button {
                                text: "Enviar"
                                flat: true
                                background: Rectangle {
                                    color: parent.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                                    radius: Radius.small
                                }
                                contentItem: Text {
                                    text: "Enviar"
                                    font.family: Typography.defaultFamily
                                    font.pixelSize: Typography.sizeCaption
                                    font.bold: true
                                    color: root.walColor5
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    if (replyField.text.trim() !== "") {
                                        root.notificationService.sendReply(popupItem.notifId, replyField.text)
                                        replyField.text = ""
                                        popupItem.removePopup()
                                    }
                                }
                            }

                            Button {
                                text: "Cancelar"
                                flat: true
                                background: Rectangle {
                                    color: parent.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                                    radius: Radius.small
                                }
                                contentItem: Text {
                                    text: "Cancelar"
                                    font.family: Typography.defaultFamily
                                    font.pixelSize: Typography.sizeCaption
                                    color: root.walColor1
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    replyField.text = ""
                                    popupItem.showingReplyInput = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
