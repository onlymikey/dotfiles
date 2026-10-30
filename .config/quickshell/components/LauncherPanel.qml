import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../theme"

PanelWindow {
    id: launcherPanel
    screen: root.panelScreen
    visible: root.launcherVisible || slideAnim.running
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    anchors { top: true; bottom: true; left: true }
    margins { top: 40; bottom: 10; left: root.launcherVisible ? 6 : -Math.round(460 * UIScale.scale) }
    implicitWidth: Math.round(420 * UIScale.scale)
    color: "transparent"
    focusable: true
    property int kbFocusMode: root.launcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.keyboardFocus: kbFocusMode
    Behavior on margins.left { NumberAnimation { id: slideAnim; duration: Animations.normal; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.7)
        radius: Radius.panel

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                color: Qt.rgba(0, 0, 0, 0.3)
                radius: Radius.large
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: Spacing.xs
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Radius.mediumSmall
                        color: root.activeTab === 0 ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.2) : "transparent"
                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: Icons.launcherTabApps
                                color: root.activeTab === 0 ? root.walColor5 : root.walColor8
                                font.pixelSize: Typography.sizeBodyLarge
                                font.family: Typography.defaultFamily
                            }
                            Text {
                                text: I18n.s.launcher_tab_apps
                                color: root.activeTab === 0 ? root.walColor5 : root.walColor8
                                font.pixelSize: Typography.sizeBodyMedium
                                font.bold: root.activeTab === 0
                                font.family: Typography.defaultFamily
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTab = 0
                                searchInput.forceActiveFocus()
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Radius.mediumSmall
                        color: root.activeTab === 1 ? Qt.rgba(root.walColor13.r, root.walColor13.g, root.walColor13.b, 0.2) : "transparent"
                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: Icons.launcherTabWallpapers
                                color: root.activeTab === 1 ? root.walColor13 : root.walColor8
                                font.pixelSize: Typography.sizeBodyLarge
                                font.family: Typography.defaultFamily
                            }
                            Text {
                                text: I18n.s.launcher_tab_walls
                                color: root.activeTab === 1 ? root.walColor13 : root.walColor8
                                font.pixelSize: Typography.sizeBodyMedium
                                font.bold: root.activeTab === 1
                                font.family: Typography.defaultFamily
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTab = 1
                                if (!root.wallsLoaded) root.loadWallpapers()
                                wallSearchInput.forceActiveFocus()
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Radius.mediumSmall

                        color: root.activeTab === 2
                            ? Qt.rgba(root.walColor2.r, root.walColor2.g, root.walColor2.b, 0.2)
                            : "transparent"

                        Behavior on color { ColorAnimation { duration: Animations.fast } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Icons.launcherTabClipboard
                                color: root.activeTab === 2 ? root.walColor2 : root.walColor8
                                font.pixelSize: Typography.sizeBodyLarge
                                font.family: Typography.defaultFamily
                            }

                            Text {
                                text: I18n.s.launcher_tab_clipboard
                                color: root.activeTab === 2 ? root.walColor2 : root.walColor8
                                font.pixelSize: Typography.sizeBodyMedium
                                font.bold: root.activeTab === 2
                                font.family: Typography.defaultFamily
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.activeTab = 2
                                root.reloadClipboard()

                                Qt.callLater(function() {
                                    clipboardSearchInput.forceActiveFocus()
                                })
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    visible: root.activeTab === 0
                    opacity: root.activeTab === 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: Radius.large
                        border.width: searchInput.activeFocus ? 1 : 0
                        border.color: root.walColor5
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10
                            Text {
                                text: ""
                                color: root.walColor8
                                font.pixelSize: Typography.sizeBodyLarge
                                font.family: Typography.defaultFamily
                            }
                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: root.walForeground
                                font.pixelSize: Typography.sizeBodyLarge
                                font.family: Typography.defaultFamily
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                clip: true
                                Text {
                                    text: I18n.s.launcher_search_apps
                                    color: root.walColor8
                                    visible: !parent.text
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    font: parent.font
                                    opacity: 0.6
                                }
                                onTextChanged: {
                                    root.searchTerm = text.toLowerCase()
                                    root.selectedIndex = 0
                                    appListView.contentY = 0
                                }
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Down) {
                                        root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredApps.length - 1)
                                        appListView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Up) {
                                        root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                                        appListView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (root.filteredApps.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredApps.length)
                                            root.launchApp(root.filteredApps[root.selectedIndex])
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Escape) {
                                        root.closeAllPanels()
                                        searchInput.text = ""
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Tab) {
                                        root.activeTab = 1
                                        if (!root.wallsLoaded) root.loadWallpapers()
                                        wallSearchInput.forceActiveFocus()
                                        event.accepted = true
                                    }
                                }
                            }
                            Text {
                                visible: searchInput.text.length > 0
                                text: Icons.close
                                color: root.walColor8
                                font.pixelSize: Typography.sizeNormal
                                font.family: Typography.defaultFamily
                                opacity: clearAppMouse.containsMouse ? 1.0 : 0.7
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                MouseArea {
                                    id: clearAppMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchInput.text = ""
                                        searchInput.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 15
                        clip: true

                        ListView {
                            id: appListView
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: Spacing.xs
                            boundsBehavior: Flickable.StopAtBounds
                            currentIndex: root.selectedIndex
                            highlightFollowsCurrentItem: true
                            highlightMoveDuration: 100
                            model: root.filteredApps

                            property real targetContentY: 0
                            property bool animatingScroll: false

                            NumberAnimation {
                                id: appScrollAnim
                                target: appListView
                                property: "contentY"
                                duration: Animations.normal
                                easing.type: Easing.OutCubic
                                onFinished: appListView.animatingScroll = false
                            }

                            function smoothScrollTo(newY) {
                                var maxY = Math.max(0, contentHeight - height)
                                newY = Math.max(0, Math.min(newY, maxY))
                                if (animatingScroll) {
                                    appScrollAnim.stop()
                                }
                                animatingScroll = true
                                appScrollAnim.from = contentY
                                appScrollAnim.to = newY
                                targetContentY = newY
                                appScrollAnim.start()
                            }

                            function smoothScrollBy(delta) {
                                var base = animatingScroll ? targetContentY : contentY
                                smoothScrollTo(base + delta)
                            }

                            MouseArea {
                                anchors.fill: parent
                                propagateComposedEvents: true
                                onWheel: function(wheel) {
                                    var step = -wheel.angleDelta.y / 120.0 * 60
                                    appListView.smoothScrollBy(step)
                                }
                                onClicked: function(mouse) { mouse.accepted = false }
                                onPressed: function(mouse) { mouse.accepted = false }
                                onReleased: function(mouse) { mouse.accepted = false }
                            }

                            delegate: Rectangle {
                                width: appListView.width
                                height: 48
                                radius: Radius.large
                                color: {
                                    if (index === root.selectedIndex)
                                        return Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.2)
                                    if (appItemMouse.containsMouse)
                                        return Qt.rgba(1, 1, 1, 0.05)
                                    return "transparent"
                                }
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Rectangle {
                                    visible: index === root.selectedIndex
                                    width: 3
                                    height: 22
                                    radius: 2
                                    color: root.walColor5
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    anchors.topMargin: 6
                                    anchors.bottomMargin: 6
                                    spacing: Spacing.md
                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: Radius.mediumSmall
                                        color: Qt.rgba(0, 0, 0, 0.2)
                                        Image {
                                            id: appIconImg
                                            anchors.centerIn: parent
                                            width: 22
                                            height: 22
                                            visible: status === Image.Ready
                                            source: {
                                                var icon = modelData.icon
                                                if (!icon || icon === "") return ""
                                                if (icon.indexOf("/") === 0) return "file://" + icon
                                                return "image://icon/" + icon
                                            }
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            cache: true
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: appIconImg.status !== Image.Ready
                                            text: Icons.launcherTabApps
                                            color: root.walColor5
                                            font.pixelSize: Typography.sizeBodyLarge
                                            font.family: Typography.defaultFamily
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            color: index === root.selectedIndex ? root.walColor5 : root.walForeground
                                            font.pixelSize: Typography.sizeBodyMedium
                                            font.family: Typography.defaultFamily
                                            font.bold: index === root.selectedIndex
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.exec
                                            color: root.walColor8
                                            font.pixelSize: Typography.sizeCaption
                                            font.family: Typography.defaultFamily
                                            elide: Text.ElideRight
                                            opacity: 0.7
                                        }
                                    }
                                    Text {
                                        visible: index === root.selectedIndex
                                        text: Icons.keyboardEnter
                                        color: root.walColor5
                                        font.pixelSize: Typography.sizeBodyLarge
                                        font.family: Typography.defaultFamily
                                        font.bold: true
                                    }
                                }
                                MouseArea {
                                    id: appItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.launchApp(modelData)
                                    onContainsMouseChanged: {
                                        if (containsMouse) root.selectedIndex = index
                                    }
                                }
                            }
                            ScrollBar.vertical: ScrollBar {
                                active: true
                                width: 4
                                policy: ScrollBar.AsNeeded
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: root.filteredApps.length === 0
                            text: I18n.s.launcher_no_apps
                            color: root.walColor8
                            font.pixelSize: Typography.sizeBodyLarge
                            font.family: Typography.defaultFamily
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: Radius.medium
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            Text { text: Icons.listNavVertical + " nav"; color: root.walColor8; font.pixelSize: Typography.sizeSmall; font.family: Typography.defaultFamily; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            Text { text: Icons.keyboardEnter + " launch"; color: root.walColor8; font.pixelSize: Typography.sizeSmall; font.family: Typography.defaultFamily; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            Text { text: "tab walls clipboard"; color: root.walColor8; font.pixelSize: Typography.sizeSmall; font.family: Typography.defaultFamily; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            Text { text: "esc close"; color: root.walColor8; font.pixelSize: Typography.sizeSmall; font.family: Typography.defaultFamily; opacity: 0.7 }
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    visible: root.activeTab === 1
                    opacity: root.activeTab === 1 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: Radius.large
                        border.width: wallSearchInput.activeFocus ? 1 : 0
                        border.color: root.walColor13
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10
                            Text {
                                text: ""
                                color: root.walColor8
                                font.pixelSize: Typography.sizeBodyLarge
                                font.family: Typography.defaultFamily
                            }
                            TextInput {
                                id: wallSearchInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: root.walForeground
                                font.pixelSize: Typography.sizeBodyLarge
                                font.family: Typography.defaultFamily
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                clip: true
                                Text {
                                    text: I18n.s.launcher_search_walls
                                    color: root.walColor8
                                    visible: !parent.text
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    font: parent.font
                                    opacity: 0.6
                                }
                                onTextChanged: {
                                    root.wallSearchTerm = text.toLowerCase()
                                    root.wallSelectedIndex = 0
                                    wallGridView.contentY = 0
                                }
                                Keys.onPressed: function(event) {
                                    var cols = 3
                                    var total = root.filteredWallpapers.length
                                    if (event.key === Qt.Key_Right) {
                                        root.wallSelectedIndex = Math.min(root.wallSelectedIndex + 1, total - 1)
                                        wallGridView.positionViewAtIndex(root.wallSelectedIndex, GridView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Left) {
                                        root.wallSelectedIndex = Math.max(root.wallSelectedIndex - 1, 0)
                                        wallGridView.positionViewAtIndex(root.wallSelectedIndex, GridView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Down) {
                                        root.wallSelectedIndex = Math.min(root.wallSelectedIndex + cols, total - 1)
                                        wallGridView.positionViewAtIndex(root.wallSelectedIndex, GridView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Up) {
                                        root.wallSelectedIndex = Math.max(root.wallSelectedIndex - cols, 0)
                                        wallGridView.positionViewAtIndex(root.wallSelectedIndex, GridView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (total > 0 && root.wallSelectedIndex >= 0 && root.wallSelectedIndex < total)
                                            root.applyWallpaper(root.filteredWallpapers[root.wallSelectedIndex])
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Escape) {
                                        root.closeAllPanels()
                                        wallSearchInput.text = ""
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Tab) {
                                        root.activeTab = 2
                                        root.reloadClipboard()

                                        Qt.callLater(function() {
                                            clipboardSearchInput.forceActiveFocus()
                                        })
                                    }
                                }
                            }
                            Text {
                                visible: wallSearchInput.text.length > 0
                                text: Icons.close
                                color: root.walColor8
                                font.pixelSize: Typography.sizeNormal
                                font.family: Typography.defaultFamily
                                opacity: clearWallMouse.containsMouse ? 1.0 : 0.7
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                MouseArea {
                                    id: clearWallMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        wallSearchInput.text = ""
                                        wallSearchInput.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 15
                        clip: true

                        GridView {
                            id: wallGridView
                            anchors.fill: parent
                            anchors.margins: 10
                            cellWidth: Math.floor(width / 3)
                            cellHeight: cellWidth * 0.65 + 30
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            cacheBuffer: 400
                            model: root.filteredWallpapers

                            property real targetContentY: 0
                            property bool animatingScroll: false

                            NumberAnimation {
                                id: wallScrollAnim
                                target: wallGridView
                                property: "contentY"
                                duration: Animations.normal
                                easing.type: Easing.OutCubic
                                onFinished: wallGridView.animatingScroll = false
                            }

                            function smoothScrollTo(newY) {
                                var maxY = Math.max(0, contentHeight - height)
                                newY = Math.max(0, Math.min(newY, maxY))
                                if (animatingScroll) {
                                    wallScrollAnim.stop()
                                }
                                animatingScroll = true
                                wallScrollAnim.from = contentY
                                wallScrollAnim.to = newY
                                targetContentY = newY
                                wallScrollAnim.start()
                            }

                            function smoothScrollBy(delta) {
                                var base = animatingScroll ? targetContentY : contentY
                                smoothScrollTo(base + delta)
                            }

                            MouseArea {
                                anchors.fill: parent
                                propagateComposedEvents: true
                                onWheel: function(wheel) {
                                    var step = -wheel.angleDelta.y / 120.0 * (wallGridView.cellHeight * 0.6)
                                    wallGridView.smoothScrollBy(step)
                                }
                                onClicked: function(mouse) { mouse.accepted = false }
                                onPressed: function(mouse) { mouse.accepted = false }
                                onReleased: function(mouse) { mouse.accepted = false }
                            }

                            delegate: Item {
                                width: wallGridView.cellWidth
                                height: wallGridView.cellHeight
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: Radius.medium
                                    color: {
                                        if (index === root.wallSelectedIndex)
                                            return Qt.rgba(root.walColor13.r, root.walColor13.g, root.walColor13.b, 0.25)
                                        if (wallItemMouse.containsMouse)
                                            return Qt.rgba(1, 1, 1, 0.08)
                                        return Qt.rgba(0, 0, 0, 0.2)
                                    }
                                    border.width: {
                                        if (modelData.path === root.currentWallpaper) return 2
                                        if (index === root.wallSelectedIndex) return 1
                                        return 0
                                    }
                                    border.color: modelData.path === root.currentWallpaper ? root.walColor2 : root.walColor13
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 2
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 7
                                                color: Qt.rgba(0.3, 0.3, 0.3, 0.3)
                                                visible: wallThumbImage.status !== Image.Ready
                                            }
                                            Image {
                                                id: wallThumbImage
                                                anchors.fill: parent
                                                source: root.thumbsReady && modelData.hash ? "file://" + Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + modelData.hash + ".jpg" : ""
                                                fillMode: Image.PreserveAspectCrop
                                                smooth: false
                                                asynchronous: true
                                                cache: true
                                                sourceSize.width: 180
                                                sourceSize.height: 120
                                                visible: false
                                                onStatusChanged: {
                                                    if (status === Image.Error && modelData.path)
                                                        source = "file://" + modelData.path
                                                }
                                            }
                                            Rectangle {
                                                id: wallThumbMaskRect
                                                anchors.fill: parent
                                                radius: 7
                                                visible: false
                                            }
                                            OpacityMask {
                                                anchors.fill: parent
                                                source: wallThumbImage
                                                maskSource: wallThumbMaskRect
                                            }
                                            Rectangle {
                                                visible: modelData.path === root.currentWallpaper
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: 3
                                                width: 16
                                                height: 16
                                                radius: Radius.mediumSmall
                                                color: root.walColor2
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: Icons.check
                                                    color: root.walBackground
                                                    font.pixelSize: Typography.sizeSmall
                                                    font.family: Typography.defaultFamily
                                                }
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 22
                                            text: modelData.name
                                            color: {
                                                if (modelData.path === root.currentWallpaper) return root.walColor2
                                                if (index === root.wallSelectedIndex) return root.walColor13
                                                return root.walForeground
                                            }
                                            font.pixelSize: Typography.sizeTiny
                                            font.family: Typography.defaultFamily
                                            font.bold: index === root.wallSelectedIndex || modelData.path === root.currentWallpaper
                                            elide: Text.ElideMiddle
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                    }
                                    MouseArea {
                                        id: wallItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.applyWallpaper(modelData)
                                        onContainsMouseChanged: {
                                            if (containsMouse) root.wallSelectedIndex = index
                                        }
                                    }
                                }
                            }
                            ScrollBar.vertical: ScrollBar {
                                active: true
                                width: 4
                                policy: ScrollBar.AsNeeded
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: root.wallsLoaded && root.filteredWallpapers.length === 0
                            text: "No wallpapers found"
                            color: root.walColor8
                            font.pixelSize: Typography.sizeBodyLarge
                            font.family: Typography.defaultFamily
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !root.wallsLoaded && root.wallpaperList.length === 0
                            text: "Loading..."
                            color: root.walColor8
                            font.pixelSize: Typography.sizeBodyMedium
                            font.family: Typography.defaultFamily
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.4; to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1.0; to: 0.4; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: Radius.medium
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            Text { text: Icons.listNavAll + " nav"; color: root.walColor8; font.pixelSize: Typography.sizeSmall; font.family: Typography.defaultFamily; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            Text { text: Icons.keyboardEnter + " apply"; color: root.walColor8; font.pixelSize: Typography.sizeSmall; font.family: Typography.defaultFamily; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            Text { text: "tab apps clipboard"; color: root.walColor8; font.pixelSize: Typography.sizeSmall; font.family: Typography.defaultFamily; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            Text { text: "esc close"; color: root.walColor8; font.pixelSize: Typography.sizeSmall; font.family: Typography.defaultFamily; opacity: 0.7 }
                        }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 15

                visible: root.activeTab === 2
                opacity: root.activeTab === 2 ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Connections {
                    target: root

                    function onActiveTabChanged() {
                        if (root.activeTab === 2) {
                            clipboardFocusTimer.start()
                        }
                    }
                }
                Timer {
                    id: clipboardFocusTimer

                    interval: 100
                    repeat: false

                    onTriggered: {
                        clipboardSearchInput.forceActiveFocus()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42

                    color: Qt.rgba(0,0,0,0.3)
                    radius: Radius.large

                    border.width: clipboardSearchInput.activeFocus ? 1 : 0
                    border.color: root.walColor5

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        TextInput {
                            id: clipboardSearchInput

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            color: root.walForeground
                            font.pixelSize: Typography.sizeBodyLarge
                            font.family: Typography.defaultFamily

                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            clip: true

                            Text {
                                text: I18n.s.launcher_search_clipboard
                                color: root.walColor8
                                visible: !parent.text
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                font: parent.font
                                opacity: 0.6
                            }

                            onTextChanged: {
                                root.clipboardSearchTerm = text.toLowerCase()
                                root.clipboardSelectedIndex = 0

                                if (clipboardListView)
                                    clipboardListView.contentY = 0
                            }

                            Keys.onPressed: function(event) {

                                if (event.key === Qt.Key_Down) {

                                    root.clipboardSelectedIndex =
                                        Math.min(
                                            root.clipboardSelectedIndex + 1,
                                            root.filteredClipboardHistory.length - 1
                                        )

                                    clipboardListView.positionViewAtIndex(
                                        root.clipboardSelectedIndex,
                                        ListView.Contain
                                    )

                                    event.accepted = true

                                } else if (event.key === Qt.Key_Up) {

                                    root.clipboardSelectedIndex =
                                        Math.max(
                                            root.clipboardSelectedIndex - 1,
                                            0
                                        )

                                    clipboardListView.positionViewAtIndex(
                                        root.clipboardSelectedIndex,
                                        ListView.Contain
                                    )

                                    event.accepted = true

                                } else if (
                                    event.key === Qt.Key_Return ||
                                    event.key === Qt.Key_Enter
                                ) {

                                    if (
                                        root.filteredClipboardHistory.length > 0 &&
                                        root.clipboardSelectedIndex >= 0 &&
                                        root.clipboardSelectedIndex < root.filteredClipboardHistory.length
                                    ) {
                                        root.restoreClipboard(
                                            root.filteredClipboardHistory[
                                                root.clipboardSelectedIndex
                                            ]
                                        )
                                    }

                                    event.accepted = true

                                } else if (event.key === Qt.Key_Escape) {

                                    root.closeAllPanels()
                                    clipboardSearchInput.text = ""

                                    event.accepted = true

                                } else if (event.key === Qt.Key_Tab) {

                                    root.activeTab = 0

                                    searchInput.forceActiveFocus()

                                    event.accepted = true
                                }
                            }
                        }

                        Text {
                            visible: clipboardSearchInput.text.length > 0

                            text: Icons.close
                            color: root.walColor8

                            font.pixelSize: Typography.sizeNormal
                            font.family: Typography.defaultFamily

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    clipboardSearchInput.text = ""
                                    clipboardSearchInput.forceActiveFocus()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    color: Qt.rgba(0,0,0,0.3)
                    radius: 15
                    clip: true

                    ListView {
                        id: clipboardListView

                        anchors.fill: parent
                        anchors.margins: 8

                        spacing: Spacing.xs

                        model: root.filteredClipboardHistory

                        delegate: Rectangle {

                            width: clipboardListView.width
                            height: 48

                            radius: Radius.large

                            color: {
                                if (index === root.clipboardSelectedIndex)
                                    return Qt.rgba(
                                        root.walColor5.r,
                                        root.walColor5.g,
                                        root.walColor5.b,
                                        0.2
                                    )

                                if (clipboardItemMouse.containsMouse)
                                    return Qt.rgba(1,1,1,0.05)

                                return "transparent"
                            }

                            Rectangle {
                                visible: index === root.clipboardSelectedIndex

                                width: 3
                                height: 22

                                radius: 2
                                color: root.walColor5

                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin: 14
                                anchors.rightMargin: 14

                                Text {
                                    Layout.fillWidth: true

                                    text: modelData.text

                                    color:
                                        index === root.clipboardSelectedIndex
                                            ? root.walColor5
                                            : root.walForeground

                                    font.pixelSize: Typography.sizeBodyMedium
                                    font.family: Typography.defaultFamily

                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: index === root.clipboardSelectedIndex

                                    text: Icons.keyboardEnter

                                    color: root.walColor5

                                    font.pixelSize: Typography.sizeBodyLarge
                                    font.family: Typography.defaultFamily
                                }
                            }

                            MouseArea {
                                id: clipboardItemMouse

                                anchors.fill: parent

                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.restoreClipboard(modelData)
                                }

                                onContainsMouseChanged: {
                                    if (containsMouse)
                                        root.clipboardSelectedIndex = index
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            active: true
                            width: 4
                            policy: ScrollBar.AsNeeded
                        }
                    }

                    Text {
                        anchors.centerIn: parent

                        visible: root.filteredClipboardHistory.length === 0

                        text: I18n.s.launcher_no_clipboard

                        color: root.walColor8

                        font.pixelSize: Typography.sizeBodyLarge
                        font.family: Typography.defaultFamily
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    color: Qt.rgba(0,0,0,0.3)
                    radius: Radius.medium

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12

                        Text {
                            text: Icons.listNavVertical + " nav"
                            color: root.walColor8
                            font.pixelSize: Typography.sizeSmall
                            opacity: 0.7
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: Icons.keyboardEnter + " copy"
                            color: root.walColor8
                            font.pixelSize: Typography.sizeSmall
                            opacity: 0.7
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "tab apps"
                            color: root.walColor8
                            font.pixelSize: Typography.sizeSmall
                            opacity: 0.7
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "esc close"
                            color: root.walColor8
                            font.pixelSize: Typography.sizeSmall
                            opacity: 0.7
                        }
                    }
                }
            }
        }
    }



Connections {
    target: root
    function onLauncherVisibleChanged() {
if (root.launcherVisible) {
    searchInput.text = ""
    wallSearchInput.text = ""
    root.selectedIndex = 0
    root.wallSelectedIndex = 0
    appListView.contentY = 0
    wallGridView.contentY = 0
    loadUsageProc.running = true
    currentWallProc.running = true

    // Kick: force Exclusive briefly so Hyprland grants keyboard focus to the layer
    launcherPanel.kbFocusMode = WlrKeyboardFocus.Exclusive
    focusDelayTimer.start()
    } else {
        focusDelayTimer.stop()
        exclusiveReleaseTimer.stop()

        // Release keyboard entirely when closed
        launcherPanel.kbFocusMode = WlrKeyboardFocus.None
        searchInput.text = ""
        wallSearchInput.text = ""
        searchInput.focus = false
        wallSearchInput.focus = false
    }
}
    function onWallSelectedIndexChanged() {
        if (root.activeTab === 1)
            wallGridView.positionViewAtIndex(root.wallSelectedIndex, GridView.Contain)
    }
}

    Timer {
    id: focusDelayTimer
    interval: 50
    repeat: false
    onTriggered: {
        if (root.activeTab === 0)
            searchInput.forceActiveFocus()
        else {
            if (!root.wallsLoaded) root.loadWallpapers()
            wallSearchInput.forceActiveFocus()
        }

        // DO NOT USE OnDemand HERE.
        // With Hyprland follow_mouse=1 + layers_hog_keyboard_focus=true
        // OnDemand causes keyboard focus to stick to the layer even after closing.
        // This results in visual focus ≠ keyboard focus until mouse moves.
        // Keep Exclusive while visible, None when closed.
        // Future me: do NOT touch this unless you want pain.
        launcherPanel.kbFocusMode = WlrKeyboardFocus.Exclusive
    }
}

    Timer {
        id: exclusiveReleaseTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (root.activeTab === 0)
                searchInput.forceActiveFocus()
            else {
                if (!root.wallsLoaded) root.loadWallpapers()
                wallSearchInput.forceActiveFocus()
            }
        }
    }
}
