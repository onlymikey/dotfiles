import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: calPanel
    visible: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true }
    margins { top: root.calendarVisible ? 40 : -450; left: 0; right: 0 }
    implicitHeight: 395
    color: "transparent"

    focusable: true
    WlrLayershell.keyboardFocus: root.calendarVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Behavior on margins.top { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

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
            radius: 20
            border.color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                // Header Navigation Row
                RowLayout {
                    Layout.fillWidth: true
                    
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 8
                        color: prevMA.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰁍"
                            color: root.walColor2
                            font.pixelSize: 14
                            font.family: "JetBrainsMono Nerd Font"
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
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 8
                        color: nextMA.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰁔"
                            color: root.walColor2
                            font.pixelSize: 14
                            font.family: "JetBrainsMono Nerd Font"
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
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        delegate: Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: root.walColor8
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
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
                    
                    Behavior on opacity { NumberAnimation { duration: 150 } }

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
                                font.pixelSize: 10
                                font.bold: isToday || isSelected
                                font.family: "JetBrainsMono Nerd Font"
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
                        text: "Events"
                        color: root.walColor8
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Qt.rgba(1, 1, 1, 0.02)
                        radius: 10
                        border.color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            Text {
                                text: "󰵙"
                                color: root.walColor8
                                font.pixelSize: 14
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Text {
                                text: "No events scheduled"
                                color: root.walColor8
                                font.pixelSize: 10
                                font.family: "JetBrainsMono Nerd Font"
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
        var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        return months[monthInt] || ""
    }
}
