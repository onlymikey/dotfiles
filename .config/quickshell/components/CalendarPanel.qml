import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"

PanelWindow {
    id: calPanel
    screen: root.panelScreen
    visible: root.calendarVisible || slideAnim.running
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    anchors { top: true; left: true; right: true }
    margins { top: root.calendarVisible ? 40 : -Math.round(450 * UIScale.scale); left: 0; right: 0 }
    implicitHeight: Math.round(405 * UIScale.scale)
    color: "transparent"

    focusable: true
    WlrLayershell.keyboardFocus: root.calendarVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Behavior on margins.top { NumberAnimation { id: slideAnim; duration: Animations.normal; easing.type: Easing.OutCubic } }

    Connections {
        target: root
        function onCalendarVisibleChanged() {
            if (root.calendarVisible) {
                focusTimer.start()
            } else {
                root.calendarService.resetToToday()
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: {
            calFocusAnchor.forceActiveFocus()
        }
    }

    FocusScope {
        id: calFocusScope
        anchors.fill: parent
        focus: root.calendarVisible
        enabled: root.calendarVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.closeAllPanels()
                event.accepted = true
            }
        }

        Item {
            id: calFocusAnchor
            focus: true
        }

        Rectangle {
            width: 320
            height: 385
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.75)
            radius: Radius.panel
            border.color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: Spacing.md

                // Header Navigation Row
                RowLayout {
                    Layout.fillWidth: true
                    
                    Rectangle {
                        width: 32
                        height: 32
                        radius: Radius.mediumSmall
                        color: prevMA.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: Icons.chevronLeft
                            color: root.walColor2
                            font.pixelSize: Typography.sizeBodyLarge
                            font.family: Typography.defaultFamily
                        }
                        
                        MouseArea {
                            id: prevMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.calendarService.prevMonth()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: getWordMonth(root.calendarService.currentMonth) + " " + root.calendarService.currentYear
                        color: root.walForeground
                        font.pixelSize: Typography.sizeBodyMedium
                        font.bold: true
                        font.family: Typography.defaultFamily
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: Radius.mediumSmall
                        color: nextMA.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: Icons.chevronRight
                            color: root.walColor2
                            font.pixelSize: Typography.sizeBodyLarge
                            font.family: Typography.defaultFamily
                        }
                        
                        MouseArea {
                            id: nextMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.calendarService.nextMonth()
                        }
                    }
                }

                // Days of Week Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    
                    Repeater {
                        model: I18n.s.cal_days
                        delegate: Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: root.walColor8
                            font.pixelSize: Typography.sizeSmall
                            font.bold: true
                            font.family: Typography.defaultFamily
                        }
                    }
                }

                // Calendar Grid
                GridLayout {
                    id: calendarGrid
                    columns: 7
                    rowSpacing: 6
                    columnSpacing: 0
                    Layout.fillWidth: true
                    
                    Behavior on opacity { NumberAnimation { duration: Animations.fast } }

                    Repeater {
                        model: root.calendarService.monthGrid

                        delegate: Rectangle {
                            id: dayCell
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 14
                            
                            property bool isCurrentMonth: modelData.getMonth() === root.calendarService.currentMonth
                            property bool isToday: calPanel.isToday(modelData)
                            property bool isSelected: calPanel.isSelected(modelData)
                            
                            color: isToday 
                                ? root.walColor2 
                                : (isSelected ? Qt.rgba(root.walColor2.r, root.walColor2.g, root.walColor2.b, 0.15) : "transparent")
                                
                            border.color: isSelected ? root.walColor2 : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.getDate().toString()
                                color: isToday 
                                    ? root.walBackground 
                                    : (isCurrentMonth ? root.walForeground : Qt.rgba(root.walForeground.r, root.walForeground.g, root.walForeground.b, 0.35))
                                font.pixelSize: Typography.sizeSmall
                                font.bold: isToday || isSelected
                                font.family: Typography.defaultFamily
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.calendarService.selectDate(modelData)
                            }
                        }
                    }
                }

                // Divider line
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.05)
                }

                // Events Section (Stretch Goal)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    
                    Text {
                        text: I18n.s.cal_events
                        color: root.walColor8
                        font.pixelSize: Typography.sizeBodySmall
                        font.bold: true
                        font.family: Typography.defaultFamily
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Qt.rgba(1, 1, 1, 0.02)
                        radius: Radius.medium
                        border.color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Spacing.sm
                            
                            Text {
                                text: Icons.calendar
                                color: root.walColor8
                                font.pixelSize: Typography.sizeBodyLarge
                                font.family: Typography.defaultFamily
                            }
                            Text {
                                text: I18n.s.cal_no_events
                                color: root.walColor8
                                font.pixelSize: Typography.sizeSmall
                                font.family: Typography.defaultFamily
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: root.calendarService
        function onMonthGridChanged() {
            gridFade.restart()
        }
    }

    SequentialAnimation {
        id: gridFade
        NumberAnimation { target: calendarGrid; property: "opacity"; to: 0.2; duration: 80 }
        NumberAnimation { target: calendarGrid; property: "opacity"; to: 1.0; duration: 120 }
    }

    function isToday(date) {
        var today = root.calendarService.today
        return date.getDate() === today.getDate() &&
               date.getMonth() === today.getMonth() &&
               date.getFullYear() === today.getFullYear()
    }

    function isSelected(date) {
        var sel = root.calendarService.selectedDate
        return date.getDate() === sel.getDate() &&
               date.getMonth() === sel.getMonth() &&
               date.getFullYear() === sel.getFullYear()
    }

    function getWordMonth(monthInt) {
        var months = I18n.s.cal_months || []
        return months[monthInt] || ""
    }
}
