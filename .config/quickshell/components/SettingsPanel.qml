import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"

PanelWindow {
    id: settingsPanel
    screen: root.panelScreen
    visible: root.settingsVisible || slideAnim.running
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    anchors { top: true; bottom: true; right: true }
    margins { top: 40; bottom: 10; right: root.settingsVisible ? 6 : -Math.round(760 * UIScale.scale) }
    implicitWidth: Math.round(720 * UIScale.scale)
    color: "transparent"
    focusable: true
    WlrLayershell.keyboardFocus: root.settingsVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Behavior on margins.right { NumberAnimation { id: slideAnim; duration: Animations.normal; easing.type: Easing.OutCubic } }

    property var monService: root.monitorService
    property var setService: root.settingsService
    property int activeTab: 0 // 0: Pantallas, 1: Idioma y Teclado, 2: Apariencia, 3: Acerca de

    Connections {
        target: root
        function onSettingsVisibleChanged() {
            if (root.settingsVisible) {
                if (settingsPanel.monService) settingsPanel.monService.refresh()
                if (settingsPanel.setService) settingsPanel.setService.refresh()
                Qt.callLater(() => setFocusAnchor.forceActiveFocus())
            }
        }
    }

    FocusScope {
        id: setFocusScope
        anchors.fill: parent
        focus: root.settingsVisible
        enabled: root.settingsVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.closeAllPanels()
                event.accepted = true
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && settingsPanel.monService.pendingConfirmation) {
                settingsPanel.monService.confirmChanges()
                event.accepted = true
            }
        }

        Item {
            id: setFocusAnchor
            focus: true
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.82)
            radius: Radius.panel
            border.width: 1
            border.color: Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.22)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                // ================= TOP HEADER =================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: Icons.settings
                        color: root.walColor5
                        font.pixelSize: Typography.sizeHeadingSmall
                        font.family: Typography.defaultFamily
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: I18n.s.settings_title
                            color: root.walForeground
                            font.pixelSize: Typography.sizeTitleSmall
                            font.bold: true
                            font.family: Typography.defaultFamily
                        }

                        Text {
                            text: I18n.s.settings_subtitle
                            color: root.walColor8
                            font.pixelSize: Typography.sizeTiny
                            font.family: Typography.defaultFamily
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Close button
                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: Radius.mediumSmall
                        color: closeMouse.containsMouse ? Qt.rgba(root.walColor1.r, root.walColor1.g, root.walColor1.b, 0.25) : Qt.rgba(0, 0, 0, 0.3)

                        Text {
                            anchors.centerIn: parent
                            text: Icons.close
                            color: closeMouse.containsMouse ? root.walColor1 : root.walColor8
                            font.pixelSize: Typography.sizeBodyMedium
                            font.family: Typography.defaultFamily
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeAllPanels()
                        }
                    }
                }

                // ================= BODY: SIDEBAR + CONTENT =================
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    // ---------- SIDEBAR TABS ----------
                    Rectangle {
                        Layout.preferredWidth: Math.round(180 * UIScale.scale)
                        Layout.fillHeight: true
                        color: Qt.rgba(0, 0, 0, 0.26)
                        radius: Radius.medium
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.05)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Repeater {
                                model: [
                                    { idx: 0, label: I18n.s.settings_tab_monitors, icon: Icons.monitor },
                                    { idx: 1, label: I18n.s.settings_tab_input, icon: Icons.language },
                                    { idx: 2, label: I18n.s.settings_tab_appearance, icon: Icons.appearance },
                                    { idx: 3, label: I18n.s.settings_tab_info, icon: Icons.info }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    radius: Radius.mediumSmall
                                    property bool isCurrent: settingsPanel.activeTab === modelData.idx
                                    color: isCurrent
                                           ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.25)
                                           : (tabHover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                    border.width: isCurrent ? 1 : 0
                                    border.color: root.walColor5
                                    Behavior on color { ColorAnimation { duration: Animations.fast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Text {
                                            text: modelData.icon
                                            color: parent.parent.isCurrent ? root.walColor5 : root.walForeground
                                            font.pixelSize: Typography.sizeBodyMedium
                                            font.family: Typography.defaultFamily
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            color: parent.parent.isCurrent ? root.walColor5 : root.walForeground
                                            font.pixelSize: Typography.sizeCaption
                                            font.bold: parent.parent.isCurrent
                                            font.family: Typography.defaultFamily
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: tabHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: settingsPanel.activeTab = modelData.idx
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true } // spacer
                        }
                    }

                    // ---------- CONTENT STACK ----------
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"

                        // ================= TAB 0: PANTALLAS =================
                        ColumnLayout {
                            anchors.fill: parent
                            visible: settingsPanel.activeTab === 0
                            spacing: 10

                            // 10s Safety Confirmation Banner
                            Rectangle {
                                visible: settingsPanel.monService.pendingConfirmation
                                Layout.fillWidth: true
                                Layout.preferredHeight: confirmCol.implicitHeight + 16
                                radius: Radius.mediumSmall
                                color: Qt.rgba(root.walColor4.r, root.walColor4.g, root.walColor4.b, 0.18)
                                border.width: 1
                                border.color: root.walColor4

                                ColumnLayout {
                                    id: confirmCol
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    Text {
                                        text: I18n.t("mon_safety_revert").replace("%1", settingsPanel.monService.revertSeconds)
                                        color: root.walColor4
                                        font.pixelSize: Typography.sizeCaption
                                        font.bold: true
                                        font.family: Typography.defaultFamily
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 26
                                            radius: Radius.small
                                            color: root.walColor2

                                            Text {
                                                anchors.centerIn: parent
                                                text: Icons.check + " " + I18n.s.mon_keep_changes
                                                color: root.walBackground
                                                font.pixelSize: Typography.sizeTiny
                                                font.bold: true
                                                font.family: Typography.defaultFamily
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: settingsPanel.monService.confirmChanges()
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 26
                                            radius: Radius.small
                                            color: Qt.rgba(root.walColor1.r, root.walColor1.g, root.walColor1.b, 0.25)
                                            border.width: 1
                                            border.color: root.walColor1

                                            Text {
                                                anchors.centerIn: parent
                                                text: I18n.s.mon_revert_now
                                                color: root.walColor1
                                                font.pixelSize: Typography.sizeTiny
                                                font.bold: true
                                                font.family: Typography.defaultFamily
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: settingsPanel.monService.revertChanges()
                                            }
                                        }
                                    }
                                }
                            }

                            // Interactive Visual Monitor Map
                            Rectangle {
                                id: setPreviewCanvas
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(110 * UIScale.scale)
                                radius: Radius.mediumSmall
                                color: Qt.rgba(0, 0, 0, 0.35)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                clip: true

                                property var layoutBounds: {
                                    var mons = settingsPanel.monService.monitors || []
                                    var minX = 99999, minY = 99999, maxX = -99999, maxY = -99999
                                    var count = 0
                                    for (var i = 0; i < mons.length; i++) {
                                        var m = mons[i]
                                        if (m.disabled) continue
                                        var x1 = m.x
                                        var y1 = m.y
                                        var ew = Math.round(m.width / Math.max(0.5, m.scale))
                                        var eh = Math.round(m.height / Math.max(0.5, m.scale))
                                        if (x1 < minX) minX = x1
                                        if (y1 < minY) minY = y1
                                        if (x1 + ew > maxX) maxX = x1 + ew
                                        if (y1 + eh > maxY) maxY = y1 + eh
                                        count++
                                    }
                                    if (count === 0) return { minX: 0, minY: 0, totalW: 1920, totalH: 1080 }
                                    return {
                                        minX: minX,
                                        minY: minY,
                                        totalW: Math.max(640, maxX - minX),
                                        totalH: Math.max(480, maxY - minY)
                                    }
                                }

                                Repeater {
                                    model: settingsPanel.monService.monitors

                                    delegate: Rectangle {
                                        required property var modelData
                                        visible: !modelData.disabled
                                        property bool isSelected: settingsPanel.monService.selectedMonitor === modelData.name
                                        property real pad: 14
                                        property real availW: Math.max(100, setPreviewCanvas.width - pad * 2)
                                        property real availH: Math.max(60, setPreviewCanvas.height - pad * 2)
                                        property real scaleFactor: Math.min(
                                            availW / setPreviewCanvas.layoutBounds.totalW,
                                            availH / setPreviewCanvas.layoutBounds.totalH
                                        )
                                        property real effW: Math.round(modelData.width / Math.max(0.5, modelData.scale))
                                        property real effH: Math.round(modelData.height / Math.max(0.5, modelData.scale))
                                        property real groupW: setPreviewCanvas.layoutBounds.totalW * scaleFactor
                                        property real groupH: setPreviewCanvas.layoutBounds.totalH * scaleFactor
                                        property real offsetX: (setPreviewCanvas.width - groupW) / 2
                                        property real offsetY: (setPreviewCanvas.height - groupH) / 2

                                        x: offsetX + (modelData.x - setPreviewCanvas.layoutBounds.minX) * scaleFactor
                                        y: offsetY + (modelData.y - setPreviewCanvas.layoutBounds.minY) * scaleFactor
                                        width: Math.max(50, effW * scaleFactor - 3)
                                        height: Math.max(30, effH * scaleFactor - 3)
                                        radius: Radius.small
                                        color: isSelected
                                               ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.34)
                                               : Qt.rgba(root.walColor8.r, root.walColor8.g, root.walColor8.b, 0.2)
                                        border.width: isSelected ? 2 : 1
                                        border.color: isSelected ? root.walColor4 : (modelData.isPrimary ? root.walColor5 : root.walColor8)

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 1

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: (modelData.isPrimary ? "★ " : "") + modelData.name
                                                color: root.walForeground
                                                font.pixelSize: Typography.sizeCaption
                                                font.bold: true
                                                font.family: Typography.defaultFamily
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.displayMode === "mirror"
                                                      ? ("Espejo")
                                                      : (modelData.res + " · " + modelData.refreshRateInt + "Hz")
                                                color: root.walColor4
                                                font.pixelSize: Typography.sizeSuperTiny
                                                font.family: Typography.defaultFamily
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: settingsPanel.monService.selectedMonitor = modelData.name
                                        }
                                    }
                                }

                                Row {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.margins: 4
                                    spacing: 4

                                    Repeater {
                                        model: settingsPanel.monService.monitors

                                        delegate: Rectangle {
                                            required property var modelData
                                            visible: modelData.disabled
                                            width: pDisTxt.implicitWidth + 12
                                            height: 20
                                            radius: Radius.small
                                            property bool isSelected: settingsPanel.monService.selectedMonitor === modelData.name
                                            color: isSelected
                                                   ? Qt.rgba(root.walColor4.r, root.walColor4.g, root.walColor4.b, 0.25)
                                                   : Qt.rgba(1, 1, 1, 0.08)
                                            border.width: 1
                                            border.color: isSelected ? root.walColor4 : root.walColor8

                                            Text {
                                                id: pDisTxt
                                                anchors.centerIn: parent
                                                text: modelData.name + " (off)"
                                                color: isSelected ? root.walColor4 : root.walColor8
                                                font.pixelSize: Typography.sizeSuperTiny
                                                font.family: Typography.defaultFamily
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: settingsPanel.monService.selectedMonitor = modelData.name
                                            }
                                        }
                                    }
                                }
                            }

                            // 4 Quick Projection Modes
                            GridLayout {
                                visible: settingsPanel.monService.connectedCount > 1
                                Layout.fillWidth: true
                                columns: 4
                                columnSpacing: 6
                                rowSpacing: 6

                                Repeater {
                                    model: [
                                        { id: "extend", label: I18n.s.mon_mode_extend, sub: I18n.t("mon_mode_extend_sub").replace("%1", settingsPanel.monService.connectedCount), icon: Icons.monitorMultiple },
                                        { id: "mirror", label: I18n.s.mon_mode_mirror, sub: "★ " + settingsPanel.monService.primaryMonitor, icon: Icons.monitorMirror },
                                        { id: "primary_only", label: I18n.s.mon_mode_primary, sub: settingsPanel.monService.primaryMonitor, icon: Icons.monitor },
                                        { id: "external_only", label: I18n.s.mon_mode_external, sub: settingsPanel.monService.effectiveSecondaryMonitor, icon: Icons.monitorLaptop }
                                    ]

                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 52
                                        radius: Radius.mediumSmall
                                        property bool isActive: settingsPanel.monService.layoutMode === modelData.id
                                        color: isActive
                                               ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.26)
                                               : (mHover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.3))
                                        border.width: 1
                                        border.color: isActive ? root.walColor5 : "transparent"

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 3
                                            spacing: 1

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.icon
                                                color: parent.parent.isActive ? root.walColor5 : root.walForeground
                                                font.pixelSize: Typography.sizeBodyMedium
                                                font.family: Typography.defaultFamily
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.label
                                                color: parent.parent.isActive ? root.walColor5 : root.walForeground
                                                font.pixelSize: Typography.sizeTiny
                                                font.bold: parent.parent.isActive
                                                font.family: Typography.defaultFamily
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                                text: modelData.sub
                                                color: parent.parent.isActive ? root.walColor4 : root.walColor8
                                                font.pixelSize: Typography.sizeSuperTiny
                                                font.family: Typography.defaultFamily
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: mHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: settingsPanel.monService.setLayoutMode(modelData.id, settingsPanel.monService.effectiveSecondaryMonitor)
                                        }
                                    }
                                }
                            }

                            // Scrollable Monitor Cards
                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentHeight: setMonCardsCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                Column {
                                    id: setMonCardsCol
                                    width: parent.width
                                    spacing: 10

                                    Repeater {
                                        model: settingsPanel.monService.monitors

                                        delegate: Rectangle {
                                            id: sMonCard
                                            required property var modelData
                                            property bool isSelected: settingsPanel.monService.selectedMonitor === modelData.name
                                            width: setMonCardsCol.width
                                            height: sCardCol.implicitHeight + 20
                                            radius: Radius.mediumSmall
                                            color: Qt.rgba(0, 0, 0, 0.3)
                                            border.width: isSelected ? 2 : 1
                                            border.color: isSelected
                                                          ? root.walColor4
                                                          : (modelData.isPrimary
                                                             ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.45)
                                                             : Qt.rgba(1, 1, 1, 0.08))

                                            property string selectedRes: modelData.res || "1920x1080"
                                            property var availableResolutions: modelData.resolutions || []
                                            property var ratesForSelectedRes: {
                                                var list = sMonCard.availableResolutions
                                                for (var i = 0; i < list.length; i++) {
                                                    if (list[i].res === sMonCard.selectedRes) return list[i].rates || []
                                                }
                                                return list.length > 0 ? (list[0].rates || []) : []
                                            }

                                            Column {
                                                id: sCardCol
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.margins: 10
                                                spacing: 8

                                                // Title Row
                                                RowLayout {
                                                    width: parent.width
                                                    spacing: 8

                                                    Text {
                                                        text: modelData.isInternal ? Icons.monitorLaptop : Icons.monitor
                                                        color: modelData.disabled ? root.walColor8 : root.walColor5
                                                        font.pixelSize: Typography.sizeTitleMedium
                                                        font.family: Typography.defaultFamily
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 1

                                                        Text {
                                                            text: modelData.name + (modelData.model ? " — " + modelData.model : "")
                                                            color: modelData.disabled ? root.walColor8 : root.walForeground
                                                            font.pixelSize: Typography.sizeCaption
                                                            font.bold: true
                                                            font.family: Typography.defaultFamily
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }

                                                        Text {
                                                            text: modelData.disabled
                                                                  ? I18n.s.mon_off
                                                                  : (modelData.displayMode === "mirror"
                                                                     ? I18n.t("mon_mirroring_to").replace("%1", modelData.mirrorOf)
                                                                     : (modelData.res + " @ " + modelData.refreshRateInt + "Hz · " + modelData.scale + "x"))
                                                            color: root.walColor8
                                                            font.pixelSize: Typography.sizeTiny
                                                            font.family: Typography.defaultFamily
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: !modelData.disabled && settingsPanel.monService.connectedCount > 1
                                                        Layout.preferredWidth: sPriTxt.implicitWidth + 12
                                                        Layout.preferredHeight: 22
                                                        radius: Radius.small
                                                        color: modelData.isPrimary
                                                               ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.25)
                                                               : Qt.rgba(1, 1, 1, 0.08)

                                                        Text {
                                                            id: sPriTxt
                                                            anchors.centerIn: parent
                                                            text: modelData.isPrimary ? I18n.s.mon_is_primary : I18n.s.mon_make_primary
                                                            color: modelData.isPrimary ? root.walColor5 : root.walForeground
                                                            font.pixelSize: Typography.sizeTiny
                                                            font.bold: modelData.isPrimary
                                                            font.family: Typography.defaultFamily
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            enabled: !modelData.isPrimary
                                                            cursorShape: modelData.isPrimary ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                            onClicked: {
                                                                settingsPanel.monService.selectedMonitor = modelData.name
                                                                settingsPanel.monService.setPrimary(modelData.name)
                                                            }
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: settingsPanel.monService.connectedCount > 1
                                                        Layout.preferredWidth: 34
                                                        Layout.preferredHeight: 18
                                                        radius: 9
                                                        color: !modelData.disabled ? root.walColor2 : Qt.rgba(1, 1, 1, 0.16)

                                                        Rectangle {
                                                            width: 14
                                                            height: 14
                                                            radius: 7
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            x: !modelData.disabled ? parent.width - width - 2 : 2
                                                            color: root.walBackground
                                                            Behavior on x { NumberAnimation { duration: Animations.fast } }
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                settingsPanel.monService.selectedMonitor = modelData.name
                                                                settingsPanel.monService.applyMonitor({
                                                                    name: modelData.name,
                                                                    enabled: modelData.disabled
                                                                })
                                                            }
                                                        }
                                                    }
                                                }

                                                // Per-Monitor Mode Row
                                                RowLayout {
                                                    visible: settingsPanel.monService.connectedCount > 1
                                                    width: parent.width
                                                    spacing: 4

                                                    Text {
                                                        text: "Modo:"
                                                        color: root.walColor8
                                                        font.pixelSize: Typography.sizeTiny
                                                        font.family: Typography.defaultFamily
                                                    }

                                                    Repeater {
                                                        model: [
                                                            { id: "extend", label: I18n.s.mon_mode_extend },
                                                            { id: "mirror", label: I18n.s.mon_mode_mirror + " ★" },
                                                            { id: "only", label: I18n.s.mon_mode_primary },
                                                            { id: "disabled", label: I18n.s.disabled }
                                                        ]

                                                        delegate: Rectangle {
                                                            required property var modelData
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: 22
                                                            radius: Radius.small
                                                            property bool isCurrent: sMonCard.modelData.displayMode === modelData.id
                                                            color: isCurrent
                                                                   ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.28)
                                                                   : Qt.rgba(1, 1, 1, 0.06)
                                                            border.width: isCurrent ? 1 : 0
                                                            border.color: root.walColor5

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: modelData.label
                                                                color: parent.isCurrent ? root.walColor5 : root.walForeground
                                                                font.pixelSize: Typography.sizeTiny
                                                                font.bold: parent.isCurrent
                                                                font.family: Typography.defaultFamily
                                                            }

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    settingsPanel.monService.selectedMonitor = sMonCard.modelData.name
                                                                    settingsPanel.monService.applyMonitor({
                                                                        name: sMonCard.modelData.name,
                                                                        mode: sMonCard.modelData.currentMode,
                                                                        scale: sMonCard.modelData.scale,
                                                                        relation: sMonCard.modelData.relation,
                                                                        displayMode: modelData.id
                                                                    })
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // Controls when enabled
                                                Column {
                                                    visible: !modelData.disabled
                                                    width: parent.width
                                                    spacing: 6

                                                    // Resolutions
                                                    Text {
                                                        text: I18n.s.mon_res_hz + ":"
                                                        color: root.walColor8
                                                        font.pixelSize: Typography.sizeTiny
                                                        font.family: Typography.defaultFamily
                                                    }

                                                    Flow {
                                                        width: parent.width
                                                        spacing: 4

                                                        Repeater {
                                                            model: sMonCard.availableResolutions.slice(0, 7)

                                                            delegate: Rectangle {
                                                                required property var modelData
                                                                width: sResTxt.implicitWidth + 12
                                                                height: 22
                                                                radius: Radius.small
                                                                property bool isCurrent: sMonCard.modelData.res === modelData.res
                                                                color: isCurrent
                                                                       ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.28)
                                                                       : Qt.rgba(1, 1, 1, 0.06)
                                                                border.width: isCurrent ? 1 : 0
                                                                border.color: root.walColor5

                                                                Text {
                                                                    id: sResTxt
                                                                    anchors.centerIn: parent
                                                                    text: modelData.res
                                                                    color: parent.isCurrent ? root.walColor5 : root.walForeground
                                                                    font.pixelSize: Typography.sizeTiny
                                                                    font.bold: parent.isCurrent
                                                                    font.family: Typography.defaultFamily
                                                                }

                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onClicked: {
                                                                        settingsPanel.monService.selectedMonitor = sMonCard.modelData.name
                                                                        sMonCard.selectedRes = modelData.res
                                                                        var topMode = (modelData.rates && modelData.rates.length > 0)
                                                                                      ? modelData.rates[0].mode
                                                                                      : (modelData.res + "@60")
                                                                        settingsPanel.monService.applyMonitor({
                                                                            name: sMonCard.modelData.name,
                                                                            mode: topMode,
                                                                            scale: sMonCard.modelData.scale,
                                                                            relation: sMonCard.modelData.relation,
                                                                            enabled: true
                                                                        })
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }

                                                    // Refresh Rate
                                                    Text {
                                                        text: "Frecuencia de actualización"
                                                        color: root.walColor8
                                                        font.pixelSize: Typography.sizeTiny
                                                        font.family: Typography.defaultFamily
                                                    }

                                                    Flow {
                                                        width: parent.width
                                                        spacing: 4

                                                        Repeater {
                                                            model: sMonCard.ratesForSelectedRes

                                                            delegate: Rectangle {
                                                                required property var modelData
                                                                width: sHzTxt.implicitWidth + 12
                                                                height: 22
                                                                radius: Radius.small
                                                                property bool isCurrent: sMonCard.modelData.refreshRateInt === modelData.hzInt
                                                                                         && sMonCard.modelData.res === sMonCard.selectedRes
                                                                color: isCurrent
                                                                       ? Qt.rgba(root.walColor4.r, root.walColor4.g, root.walColor4.b, 0.28)
                                                                       : Qt.rgba(1, 1, 1, 0.06)
                                                                border.width: isCurrent ? 1 : 0
                                                                border.color: root.walColor4

                                                                Text {
                                                                    id: sHzTxt
                                                                    anchors.centerIn: parent
                                                                    text: modelData.label
                                                                    color: parent.isCurrent ? root.walColor4 : root.walForeground
                                                                    font.pixelSize: Typography.sizeTiny
                                                                    font.bold: parent.isCurrent
                                                                    font.family: Typography.defaultFamily
                                                                }

                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onClicked: {
                                                                        settingsPanel.monService.selectedMonitor = sMonCard.modelData.name
                                                                        settingsPanel.monService.applyMonitor({
                                                                            name: sMonCard.modelData.name,
                                                                            mode: modelData.mode,
                                                                            scale: sMonCard.modelData.scale,
                                                                            relation: sMonCard.modelData.relation,
                                                                            enabled: true
                                                                        })
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }

                                                    // Scale
                                                    RowLayout {
                                                        width: parent.width
                                                        spacing: 4

                                                        Text {
                                                            text: I18n.s.mon_scale + ":"
                                                            color: root.walColor8
                                                            font.pixelSize: Typography.sizeTiny
                                                            font.family: Typography.defaultFamily
                                                        }

                                                        Repeater {
                                                            model: [0.75, 1.0, 1.25, 1.5, 2.0]

                                                            delegate: Rectangle {
                                                                required property var modelData
                                                                Layout.fillWidth: true
                                                                Layout.preferredHeight: 22
                                                                radius: Radius.small
                                                                property bool isCurrent: Math.abs(sMonCard.modelData.scale - modelData) < 0.05
                                                                color: isCurrent
                                                                       ? Qt.rgba(root.walColor13.r, root.walColor13.g, root.walColor13.b, 0.28)
                                                                       : Qt.rgba(1, 1, 1, 0.06)
                                                                border.width: isCurrent ? 1 : 0
                                                                border.color: root.walColor13

                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    text: modelData + "x"
                                                                    color: parent.isCurrent ? root.walColor13 : root.walForeground
                                                                    font.pixelSize: Typography.sizeTiny
                                                                    font.bold: parent.isCurrent
                                                                    font.family: Typography.defaultFamily
                                                                }

                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onClicked: {
                                                                        settingsPanel.monService.selectedMonitor = sMonCard.modelData.name
                                                                        settingsPanel.monService.applyMonitor({
                                                                            name: sMonCard.modelData.name,
                                                                            mode: sMonCard.modelData.currentMode,
                                                                            scale: modelData,
                                                                            relation: sMonCard.modelData.relation,
                                                                            enabled: true
                                                                        })
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }

                                                    // Relative Position (Extend mode)
                                                    RowLayout {
                                                        visible: !sMonCard.modelData.isPrimary && sMonCard.modelData.displayMode === "extend"
                                                        width: parent.width
                                                        spacing: 4

                                                        Text {
                                                            text: I18n.s.mon_position + ":"
                                                            color: root.walColor8
                                                            font.pixelSize: Typography.sizeTiny
                                                            font.family: Typography.defaultFamily
                                                        }

                                                        Repeater {
                                                            model: [
                                                                { id: "left", label: I18n.s.mon_pos_left },
                                                                { id: "right", label: I18n.s.mon_pos_right },
                                                                { id: "above", label: I18n.s.mon_pos_above },
                                                                { id: "below", label: I18n.s.mon_pos_below }
                                                            ]

                                                            delegate: Rectangle {
                                                                required property var modelData
                                                                Layout.fillWidth: true
                                                                Layout.preferredHeight: 22
                                                                radius: Radius.small
                                                                property bool isCurrent: sMonCard.modelData.relation === modelData.id
                                                                color: isCurrent
                                                                       ? Qt.rgba(root.walColor2.r, root.walColor2.g, root.walColor2.b, 0.25)
                                                                       : Qt.rgba(1, 1, 1, 0.06)
                                                                border.width: isCurrent ? 1 : 0
                                                                border.color: root.walColor2

                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    text: modelData.label
                                                                    color: parent.isCurrent ? root.walColor2 : root.walForeground
                                                                    font.pixelSize: Typography.sizeTiny
                                                                    font.bold: parent.isCurrent
                                                                    font.family: Typography.defaultFamily
                                                                }

                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onClicked: {
                                                                        settingsPanel.monService.selectedMonitor = sMonCard.modelData.name
                                                                        settingsPanel.monService.applyMonitor({
                                                                            name: sMonCard.modelData.name,
                                                                            mode: sMonCard.modelData.currentMode,
                                                                            scale: sMonCard.modelData.scale,
                                                                            relation: modelData.id,
                                                                            displayMode: "extend",
                                                                            enabled: true
                                                                        })
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

                        // ================= TAB 1: IDIOMA Y ENTRADA =================
                        Flickable {
                            anchors.fill: parent
                            visible: settingsPanel.activeTab === 1
                            contentHeight: langContentCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            Column {
                                id: langContentCol
                                width: parent.width
                                spacing: 14

                                // --- UI LANGUAGE SECTION ---
                                Rectangle {
                                    width: parent.width
                                    height: uiLangCol.implicitHeight + 24
                                    radius: Radius.medium
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.07)

                                    Column {
                                        id: uiLangCol
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            width: parent.width
                                            spacing: 8

                                            Text {
                                                text: Icons.language
                                                color: root.walColor5
                                                font.pixelSize: Typography.sizeTitleMedium
                                                font.family: Typography.defaultFamily
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                Text {
                                                    text: I18n.s.shell_lang_title
                                                    color: root.walForeground
                                                    font.pixelSize: Typography.sizeCaption
                                                    font.bold: true
                                                    font.family: Typography.defaultFamily
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: I18n.s.shell_lang_desc
                                                    color: root.walColor8
                                                    font.pixelSize: Typography.sizeTiny
                                                    font.family: Typography.defaultFamily
                                                    wrapMode: Text.WordWrap
                                                }
                                            }
                                        }

                                        RowLayout {
                                            width: parent.width
                                            spacing: 8

                                            // Spanish Option
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 38
                                                radius: Radius.small
                                                property bool isSelected: settingsPanel.setService.language === "es"
                                                color: isSelected
                                                       ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.28)
                                                       : Qt.rgba(1, 1, 1, 0.06)
                                                border.width: isSelected ? 1 : 0
                                                border.color: root.walColor5

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 12
                                                    spacing: 8

                                                    Text {
                                                        text: "🇲🇽"
                                                        font.pixelSize: Typography.sizeBodySmall
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: I18n.s.lang_es
                                                        color: parent.parent.isSelected ? root.walColor5 : root.walForeground
                                                        font.pixelSize: Typography.sizeCaption
                                                        font.bold: parent.parent.isSelected
                                                        font.family: Typography.defaultFamily
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsPanel.setService.setLanguage("es")
                                                }
                                            }

                                            // English Option
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 38
                                                radius: Radius.small
                                                property bool isSelected: settingsPanel.setService.language === "en"
                                                color: isSelected
                                                       ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.28)
                                                       : Qt.rgba(1, 1, 1, 0.06)
                                                border.width: isSelected ? 1 : 0
                                                border.color: root.walColor5

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 12
                                                    spacing: 8

                                                    Text {
                                                        text: "🇺🇸"
                                                        font.pixelSize: Typography.sizeBodySmall
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: I18n.s.lang_en
                                                        color: parent.parent.isSelected ? root.walColor5 : root.walForeground
                                                        font.pixelSize: Typography.sizeCaption
                                                        font.bold: parent.parent.isSelected
                                                        font.family: Typography.defaultFamily
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsPanel.setService.setLanguage("en")
                                                }
                                            }
                                        }
                                    }
                                }

                                // --- KEYBOARD LAYOUT SECTION ---
                                Rectangle {
                                    width: parent.width
                                    height: kbdCol.implicitHeight + 24
                                    radius: Radius.medium
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.07)

                                    Column {
                                        id: kbdCol
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 12
                                        spacing: 10

                                        RowLayout {
                                            width: parent.width
                                            spacing: 8

                                            Text {
                                                text: Icons.keyboard
                                                color: root.walColor4
                                                font.pixelSize: Typography.sizeTitleMedium
                                                font.family: Typography.defaultFamily
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                Text {
                                                    text: I18n.s.kbd_title
                                                    color: root.walForeground
                                                    font.pixelSize: Typography.sizeCaption
                                                    font.bold: true
                                                    font.family: Typography.defaultFamily
                                                }

                                                Text {
                                                    text: I18n.t("kbd_active").replace("%1", settingsPanel.setService.activeKeymap)
                                                    color: root.walColor8
                                                    font.pixelSize: Typography.sizeTiny
                                                    font.family: Typography.defaultFamily
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        // Keyboard Distribution Grid
                                        GridLayout {
                                            width: parent.width
                                            columns: 2
                                            columnSpacing: 8
                                            rowSpacing: 8

                                            Repeater {
                                                model: [
                                                    {
                                                        layout: "us",
                                                        variant: "intl",
                                                        title: I18n.s.kbd_us_intl,
                                                        desc: I18n.s.kbd_us_intl_desc
                                                    },
                                                    {
                                                        layout: "latam",
                                                        variant: "",
                                                        title: I18n.s.kbd_latam,
                                                        desc: I18n.s.kbd_latam_desc
                                                    },
                                                    {
                                                        layout: "es",
                                                        variant: "",
                                                        title: I18n.s.kbd_es,
                                                        desc: I18n.s.kbd_es_desc
                                                    },
                                                    {
                                                        layout: "us",
                                                        variant: "",
                                                        title: I18n.s.kbd_us,
                                                        desc: I18n.s.kbd_us_desc
                                                    }
                                                ]

                                                delegate: Rectangle {
                                                    id: kbdCard
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 60
                                                    radius: Radius.small
                                                    property bool isSelected: settingsPanel.setService.keyboardLayout === modelData.layout
                                                                             && settingsPanel.setService.keyboardVariant === modelData.variant
                                                    color: isSelected
                                                           ? Qt.rgba(root.walColor4.r, root.walColor4.g, root.walColor4.b, 0.25)
                                                           : Qt.rgba(1, 1, 1, 0.05)
                                                    border.width: isSelected ? 1 : 0
                                                    border.color: root.walColor4

                                                    ColumnLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 8
                                                        spacing: 2

                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 6
                                                            Text {
                                                                text: kbdCard.isSelected ? Icons.check : Icons.keyboard
                                                                color: kbdCard.isSelected ? root.walColor4 : root.walColor8
                                                                font.pixelSize: Typography.sizeTiny
                                                                font.family: Typography.defaultFamily
                                                            }
                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: modelData.title
                                                                color: kbdCard.isSelected ? root.walColor4 : root.walForeground
                                                                font.pixelSize: Typography.sizeCaption
                                                                font.bold: kbdCard.isSelected
                                                                font.family: Typography.defaultFamily
                                                                elide: Text.ElideRight
                                                            }
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: modelData.desc
                                                            color: root.walColor8
                                                            font.pixelSize: Typography.sizeSuperTiny
                                                            font.family: Typography.defaultFamily
                                                            elide: Text.ElideRight
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: settingsPanel.setService.setKeyboardLayout(modelData.layout, modelData.variant)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // --- REGIONAL LOCALE SECTION ---
                                Rectangle {
                                    width: parent.width
                                    height: locCol.implicitHeight + 20
                                    radius: Radius.medium
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.07)

                                    Column {
                                        id: locCol
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 12
                                        spacing: 6

                                        Text {
                                            text: I18n.s.posix_title
                                            color: root.walForeground
                                            font.pixelSize: Typography.sizeCaption
                                            font.bold: true
                                            font.family: Typography.defaultFamily
                                        }

                                        Text {
                                            text: I18n.t("posix_desc").replace("%1", settingsPanel.setService.systemLocale)
                                            color: root.walColor8
                                            font.pixelSize: Typography.sizeTiny
                                            font.family: Typography.defaultFamily
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }
                                    }
                                }
                            }
                        }

                        // ================= TAB 2: APARIENCIA =================
                        ColumnLayout {
                            anchors.fill: parent
                            visible: settingsPanel.activeTab === 2
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: apCol.implicitHeight + 24
                                radius: Radius.medium
                                color: Qt.rgba(0, 0, 0, 0.3)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.07)

                                Column {
                                    id: apCol
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 14
                                    spacing: 10

                                    Text {
                                        text: I18n.s.app_scaling_title
                                        color: root.walForeground
                                        font.pixelSize: Typography.sizeCaption
                                        font.bold: true
                                        font.family: Typography.defaultFamily
                                    }

                                    Text {
                                        width: parent.width
                                        text: I18n.t("app_scaling_sub").replace("%1", UIScale.scale.toFixed(2)).replace("%2", (UIScale.isLowDpi ? I18n.s.app_dpi_std : I18n.s.app_dpi_hi))
                                        color: root.walColor8
                                        font.pixelSize: Typography.sizeTiny
                                        font.family: Typography.defaultFamily
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        text: I18n.s.app_scaling_desc
                                        color: root.walColor8
                                        font.pixelSize: Typography.sizeTiny
                                        font.family: Typography.defaultFamily
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }

                        // ================= TAB 3: ACERCA DE =================
                        ColumnLayout {
                            anchors.fill: parent
                            visible: settingsPanel.activeTab === 3
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: infoCol.implicitHeight + 24
                                radius: Radius.medium
                                color: Qt.rgba(0, 0, 0, 0.3)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.07)

                                Column {
                                    id: infoCol
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 14
                                    spacing: 10

                                    RowLayout {
                                        width: parent.width
                                        spacing: 12

                                        Text {
                                            text: Icons.arch
                                            color: root.walColor5
                                            font.pixelSize: Typography.sizeHeadingLarge
                                            font.family: Typography.defaultFamily
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                Layout.fillWidth: true
                                                text: I18n.s.info_edition
                                                color: root.walForeground
                                                font.pixelSize: Typography.sizeBodyLarge
                                                font.bold: true
                                                font.family: Typography.defaultFamily
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: I18n.s.info_stack
                                                color: root.walColor8
                                                font.pixelSize: Typography.sizeTiny
                                                font.family: Typography.defaultFamily
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                    }

                                    ColumnLayout {
                                        spacing: 4
                                        Text {
                                            text: I18n.t("info_host").replace("%1", settingsPanel.setService.hostName)
                                            color: root.walColor8
                                            font.pixelSize: Typography.sizeCaption
                                            font.family: Typography.defaultFamily
                                        }
                                        Text {
                                            text: I18n.t("info_kernel").replace("%1", settingsPanel.setService.kernelVersion)
                                            color: root.walColor8
                                            font.pixelSize: Typography.sizeCaption
                                            font.family: Typography.defaultFamily
                                        }
                                        Text {
                                            text: I18n.t("info_locale").replace("%1", settingsPanel.setService.systemLocale)
                                            color: root.walColor8
                                            font.pixelSize: Typography.sizeCaption
                                            font.family: Typography.defaultFamily
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }
    }
}
