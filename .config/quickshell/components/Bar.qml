import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"

PanelWindow {
    id: bar
    visible: true
    exclusionMode: ExclusionMode.Exclusive
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell"
    anchors { top: true; left: true; right: true }
    margins { top: 0; left: 0; right: 0 }
    implicitHeight: 32
    color: "transparent"

    property color notchColor: Qt.rgba(0, 0, 0, 0.38)
    property color notchHoverColor: Qt.rgba(0, 0, 0, 0.52)
    property int notchRadius: 12
    property int notchHeight: 32

    property int activeWsId: 1
    property int targetWsId: 1
    property string mediaText: ""
    property string mediaClass: "stopped"
    property real mediaPosition: 0
    property real mediaLength: 0
    property int volumePercent: root.audioService.volume
    property bool volumeMuted: root.audioService.muted
    property string volumeStr: volumeMuted ? Icons.audioMute + " mute" : (volumePercent > 50 ? Icons.audioVolumeHigh : (volumePercent > 0 ? Icons.audioVolumeMedium : Icons.audioVolumeLow)) + " " + volumePercent + "%"
    property bool wifiConnected: root.networkService.connectedNetwork !== null
    property string wifiSSID: root.networkService.connectedNetwork ? root.networkService.connectedNetwork.ssid : ""
    property int wifiStrength: root.networkService.connectedNetwork ? root.networkService.connectedNetwork.signal : 0
    property bool btConnected: root.bluetoothService.connectedDevices.length > 0
    property int batteryPercent: 0
    property bool batteryCharging: false
    property string batteryClass: ""
    property string batteryTime: ""
    property var cavaValues: [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
    property real chargingPulse: 1.0
    property real chargingFillAnim: 0.0

    SequentialAnimation {
        id: chargingPulseAnim
        running: bar.batteryCharging
        loops: Animation.Infinite
        NumberAnimation { target: bar; property: "chargingPulse"; to: 0.3; duration: Animations.slow; easing.type: Easing.InOutSine }
        NumberAnimation { target: bar; property: "chargingPulse"; to: 1; duration: Animations.slow; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: chargingFillAnimSeq
        running: bar.batteryCharging
        loops: Animation.Infinite
        NumberAnimation { target: bar; property: "chargingFillAnim"; to: 1; duration: 2000; easing.type: Easing.InOutSine }
        NumberAnimation { target: bar; property: "chargingFillAnim"; to: 0; duration: 2000; easing.type: Easing.InOutSine }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace") {
                var wsId = parseInt(event.data.trim())
                if (!isNaN(wsId)) {
                    bar.targetWsId = wsId
                    wsTransition.restart()
                }
            } else if (event.name === "focusedmon") {
                var parts = event.data.split(",")
                if (parts.length >= 2) {
                    var wsId = parseInt(parts[1])
                    if (!isNaN(wsId)) {
                        bar.targetWsId = wsId
                        wsTransition.restart()
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: wsTransition
        PropertyAnimation {
            target: wsHighlight
            property: "highlightOpacity"
            to: 0.4
            duration: 50
            easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: bar.activeWsId = bar.targetWsId
        }
        ParallelAnimation {
            PropertyAnimation {
                target: wsHighlight
                property: "highlightOpacity"
                to: 1
                duration: Animations.normal
                easing.type: Easing.OutCubic
            }
            PropertyAnimation {
                target: wsHighlight
                property: "highlightScale"
                from: 0.9
                to: 1.0
                duration: Animations.normal
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
        }
    }

    Component.onCompleted: {
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
            bar.activeWsId = Hyprland.focusedMonitor.activeWorkspace.id
            bar.targetWsId = bar.activeWsId
        }
    }

    Timer {
        interval: 50
        running: bar.mediaClass === "playing"
        repeat: true
        onTriggered: {
            var newVals = []
            for (var i = 0; i < 12; i++) {
                var current = bar.cavaValues[i]
                var target = Math.random() * 0.75 + 0.15
                newVals.push(current * 0.35 + target * 0.65)
            }
            bar.cavaValues = newVals
        }
    }

    Timer {
        interval: 60
        running: bar.mediaClass !== "playing"
        repeat: true
        onTriggered: {
            var newVals = []
            for (var i = 0; i < 12; i++) {
                newVals.push(bar.cavaValues[i] * 0.85)
            }
            bar.cavaValues = newVals
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!mediaProc.running) mediaProc.running = true }
    }

    Process {
        id: mediaProc
        command: ["bash", "-c", "status=$(playerctl --player=%any status 2>/dev/null); pos=$(playerctl --player=%any position 2>/dev/null | cut -d. -f1); len=$(playerctl --player=%any metadata mpris:length 2>/dev/null); len=$((len / 1000000)); if [ \"$status\" = \"Playing\" ] || [ \"$status\" = \"Paused\" ]; then artist=$(playerctl --player=%any metadata artist 2>/dev/null); title=$(playerctl --player=%any metadata title 2>/dev/null); if [ -n \"$title\" ]; then text=\"$title\"; [ -n \"$artist\" ] && text=\"$artist - $title\"; if [ ${#text} -gt 35 ]; then text=\"${text:0:32}...\"; fi; echo \"$status|$text|$pos|$len\"; else echo 'stopped||0|0'; fi; else echo 'stopped||0|0'; fi"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|")
                if (parts.length >= 4) {
                    bar.mediaClass = parts[0].toLowerCase()
                    bar.mediaText = parts[1]
                    bar.mediaPosition = parseInt(parts[2]) || 0
                    bar.mediaLength = parseInt(parts[3]) || 0
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: bar.mediaClass === "playing"
        repeat: true
        onTriggered: {
            if (bar.mediaPosition < bar.mediaLength) {
                bar.mediaPosition += 1
            }
        }
    }

    function adjustVolume(delta) {
        var nextVolume = Math.max(0, Math.min(100, bar.volumePercent + delta))
        root.audioService.setVolume(nextVolume)
    }



    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!batteryProc.running) batteryProc.running = true }
    }

    Process {
        id: batteryProc
        command: ["bash", "-c", "cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1); time=''; if command -v upower >/dev/null 2>&1; then if [ \"$status\" = \"Discharging\" ]; then time=$(upower -i $(upower -e | grep BAT) 2>/dev/null | grep 'time to empty' | awk '{print $4 $5}'); elif [ \"$status\" = \"Charging\" ]; then time=$(upower -i $(upower -e | grep BAT) 2>/dev/null | grep 'time to full' | awk '{print $4 $5}'); fi; fi; [ -z \"$cap\" ] && cap=0; echo \"$cap|$status|$time\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|")
                bar.batteryPercent = parseInt(parts[0]) || 0
                var status = parts.length > 1 ? parts[1] : ""
                bar.batteryCharging = status === "Charging"
                bar.batteryTime = parts.length > 2 ? parts[2] : ""
                if (bar.batteryCharging) bar.batteryClass = "charging"
                else if (bar.batteryPercent <= 10) bar.batteryClass = "critical"
                else if (bar.batteryPercent <= 25) bar.batteryClass = "warning"
                else bar.batteryClass = ""
            }
        }
    }



    Process {
        id: mediaPlayPauseProc
        command: ["playerctl", "play-pause"]
        onExited: { if (!mediaProc.running) mediaProc.running = true }
    }

    Process {
        id: mediaNextProc
        command: ["playerctl", "next"]
        onExited: { if (!mediaProc.running) mediaProc.running = true }
    }

    Process {
        id: mediaPrevProc
        command: ["playerctl", "previous"]
        onExited: { if (!mediaProc.running) mediaProc.running = true }
    }

    component Notch: Item {
        id: notchRoot
        property bool hovered: false
        property string tooltip: ""
        default property alias content: contentItem.data

        height: bar.notchHeight

        Item {
            anchors.fill: parent
            anchors.bottomMargin: 4
            clip: true

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -bar.notchRadius
                width: parent.width
                height: parent.height + bar.notchRadius
                radius: bar.notchRadius
                antialiasing: true

                gradient: Gradient {
                    GradientStop { position: 0.0; color: notchRoot.hovered ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.30) }
                    GradientStop { position: 1.0; color: notchRoot.hovered ? bar.notchHoverColor : bar.notchColor }
                }
            }
        }

        Rectangle {
            id: tooltipBg
            visible: notchRoot.hovered && notchRoot.tooltip !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 4
            width: tooltipText.implicitWidth + 16
            height: tooltipText.implicitHeight + 8
            radius: Radius.small
            color: Qt.rgba(0, 0, 0, 0.85)
            opacity: visible ? 1 : 0
            z: 1000

            Behavior on opacity { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }

            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: notchRoot.tooltip
                color: root.walForeground
                font.pixelSize: Typography.sizeSmall
                font.family: Typography.defaultFamily
            }
        }

        Item {
            id: contentItem
            anchors.fill: parent
            anchors.bottomMargin: 4
        }
    }

    Item {
        anchors.fill: parent

        Row {
            id: leftSection
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 8
            height: bar.notchHeight
            spacing: 6

            Notch {
                width: 36
                hovered: appsMA.containsMouse
                tooltip: "Apps / Wallpapers"

                Item {
                    anchors.fill: parent

                    Text {
                        anchors.centerIn: parent
                        text: Icons.arch
                        color: root.walColor1
                        font.pixelSize: Typography.sizeTitleSmall
                        font.family: Typography.defaultFamily
                    }
                }

                MouseArea {
                    id: appsMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            root.activeTab = 1
                            if (!root.launcherVisible) root.toggleLauncher()
                            else { root.activeTab = 1; if (!root.wallsLoaded) root.loadWallpapers() }
                        } else {
                            root.activeTab = 0
                            root.toggleLauncher()
                        }
                    }
                }
            }



            Notch {
                id: workspacesNotch
                width: wsContainer.width + 20

                Behavior on width { NumberAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }

                Item {
                    anchors.fill: parent

                    Item {
                        id: wsContainer
                        anchors.centerIn: parent
                        width: wsRow.width
                        height: 18

                        Rectangle {
                            id: wsHighlight
                            height: 18
                            radius: 9

                            property real targetX: 0
                            property real targetWidth: 26
                            property real highlightOpacity: 1.0
                            property real highlightScale: 1.0

                            x: targetX
                            width: targetWidth
                            opacity: highlightOpacity
                            scale: highlightScale
                            transformOrigin: Item.Center
                            color: root.walColor13
                            antialiasing: true

                            Behavior on x {
                                NumberAnimation {
                                    duration: Animations.normal
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Row {
                            id: wsRow
                            anchors.centerIn: parent
                            spacing: Spacing.xs

                            Repeater {
                                id: wsRepeater
                                model: Hyprland.workspaces

                                delegate: Item {
                                    id: wsDelegate
                                    required property var modelData
                                    property bool isActive: bar.activeWsId === modelData.id
                                    property bool isHovered: wsMA.containsMouse

                                    width: Math.max(wsText.implicitWidth + 14, 26)
                                    height: 18

                                    onIsActiveChanged: updateHighlight()
                                    onXChanged: if (isActive) updateHighlight()
                                    onWidthChanged: if (isActive) updateHighlight()
                                    Component.onCompleted: if (isActive) updateHighlight()

                                    function updateHighlight() {
                                        if (isActive) {
                                            wsHighlight.targetX = x
                                            wsHighlight.targetWidth = width
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 9
                                        color: isHovered && !isActive ? Qt.rgba(root.walColor13.r, root.walColor13.g, root.walColor13.b, 0.3) : "transparent"
                                        antialiasing: true
                                        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }

                                    Text {
                                        id: wsText
                                        anchors.centerIn: parent
                                        text: modelData.name || modelData.id.toString()
                                        color: isActive ? root.walBackground : (isHovered ? root.walForeground : Qt.rgba(root.walForeground.r, root.walForeground.g, root.walForeground.b, 0.5))
                                        font.pixelSize: Typography.sizeSmall
                                        font.bold: true
                                        font.family: Typography.defaultFamily

                                        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }

                                    MouseArea {
                                        id: wsMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Hyprland.dispatch("workspace " + modelData.id)
                                    }
                                }
                            }
                        }

                        Connections {
                            target: bar
                            function onActiveWsIdChanged() {
                                for (var i = 0; i < wsRepeater.count; i++) {
                                    var item = wsRepeater.itemAt(i)
                                    if (item && item.isActive) {
                                        item.updateHighlight()
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            spacing: Spacing.sm

            // Clock Notch
            Notch {
                id: clockNotch
                width: clockContent.implicitWidth + 24
                hovered: clockMA.containsMouse
                tooltip: Qt.formatDateTime(new Date(), "dddd, MMMM d, yyyy")

                Behavior on width { NumberAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }

                Item {
                    anchors.fill: parent

                    Row {
                        id: clockContent
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            id: clockTime
                            text: Qt.formatDateTime(new Date(), "hh:mm AP")
                            color: root.walColor5
                            font.pixelSize: Typography.sizeBodySmall
                            font.bold: true
                            font.family: Typography.defaultFamily
                        }

                        Text {
                            id: clockSeparator
                            text: Icons.separatorDot
                            color: root.walColor5
                            font.pixelSize: Typography.sizeBodySmall
                            font.bold: true
                            font.family: Typography.defaultFamily
                            
                            // Animate layout width
                            property real targetWidth: !mediaNotch.visible ? implicitWidth : 0
                            width: targetWidth
                            clip: true
                            opacity: !mediaNotch.visible ? 1.0 : 0.0

                            Behavior on width { NumberAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        Text {
                            id: clockDate
                            text: Qt.formatDateTime(new Date(), "dd MMM")
                            color: root.walColor5
                            font.pixelSize: Typography.sizeBodySmall
                            font.bold: true
                            font.family: Typography.defaultFamily
                            
                            // Animate layout width
                            property real targetWidth: !mediaNotch.visible ? implicitWidth : 0
                            width: targetWidth
                            clip: true
                            opacity: !mediaNotch.visible ? 1.0 : 0.0

                            Behavior on width { NumberAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                    }
                }

                MouseArea {
                    id: clockMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.panelManager.toggle("calendar")
                }

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: {
                        var now = new Date()
                        clockTime.text = Qt.formatDateTime(now, "hh:mm AP")
                        clockDate.text = Qt.formatDateTime(now, "dd MMM")
                    }
                }
            }

            // Music/Media Notch
            Notch {
                id: mediaNotch
                width: bar.mediaText !== "" ? mediaContent.width + 28 : 0
                visible: bar.mediaText !== ""
                hovered: mediaMA.containsMouse
                tooltip: bar.mediaText

                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                Item {
                    anchors.fill: parent

                    Column {
                        id: mediaContent
                        anchors.centerIn: parent
                        spacing: 2

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Repeater {
                                    model: 12

                                    Rectangle {
                                        width: 2
                                        height: Math.max(2, bar.cavaValues[index] * 12)
                                        radius: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: root.walColor2
                                        opacity: bar.mediaClass === "playing" ? 0.85 : 0.25
                                        antialiasing: true

                                        Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                                        Behavior on opacity { NumberAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: bar.mediaText
                                color: root.walColor2
                                font.pixelSize: Typography.sizeSmall
                                font.bold: true
                                font.family: Typography.defaultFamily
                                opacity: bar.mediaClass === "playing" ? 1.0 : 0.6

                                Behavior on opacity { NumberAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }
                            }
                        }

                        Rectangle {
                            width: mediaContent.width
                            height: 2
                            radius: 1
                            color: Qt.rgba(root.walColor2.r, root.walColor2.g, root.walColor2.b, 0.2)
                            visible: bar.mediaLength > 0

                            Rectangle {
                                width: bar.mediaLength > 0 ? parent.width * (bar.mediaPosition / bar.mediaLength) : 0
                                height: parent.height
                                radius: 1
                                color: root.walColor2
                                opacity: 0.8

                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.Linear } }
                            }
                        }
                    }
                }

                MouseArea {
                    id: mediaMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton)
                            root.toggleMusic()
                        else if (mouse.button === Qt.MiddleButton) {
                            if (!mediaNextProc.running) mediaNextProc.running = true
                        } else {
                            if (!mediaPlayPauseProc.running) mediaPlayPauseProc.running = true
                        }
                    }
                    onWheel: function(wheel) {
                        if (wheel.angleDelta.y > 0) {
                            if (!mediaNextProc.running) mediaNextProc.running = true
                        } else {
                            if (!mediaPrevProc.running) mediaPrevProc.running = true
                        }
                    }
                }
            }

            // Notification Notch
            Notch {
                id: notificationNotch
                width: notifContent.width + 24
                visible: true
                hovered: notifMA.containsMouse
                tooltip: root.notificationService.dnd ? "Do Not Disturb Enabled" : (root.notificationService.unreadCount > 0 ? root.notificationService.unreadCount + " unread notifications" : "No unread notifications")

                Item {
                    anchors.fill: parent

                    Row {
                        id: notifContent
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.notificationService.dnd ? Icons.notificationDnd : (root.notificationService.unreadCount > 0 ? Icons.notificationActive : Icons.notificationActive)
                            color: root.notificationService.dnd ? root.walColor1 : (root.notificationService.unreadCount > 0 ? root.walColor2 : root.walColor5)
                            font.pixelSize: Typography.sizeBodyMedium
                            font.family: Typography.defaultFamily
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.notificationService.unreadCount > 0
                            text: root.notificationService.unreadCount.toString()
                            color: root.walColor2
                            font.pixelSize: Typography.sizeSmall
                            font.bold: true
                            font.family: Typography.defaultFamily
                        }
                    }

                    MouseArea {
                        id: notifMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.panelManager.toggle("notifications")
                    }
                }
            }
        }

        Row {
            id: rightSection
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 8
            height: bar.notchHeight
            spacing: 6

            // System Tray Notch
            Notch {
                id: trayNotch
                visible: root.trayService.count > 0
                width: visible ? (trayRow.width + 20) : 0
                hovered: trayHoverArea.containsMouse
                tooltip: "System Tray"

                MouseArea {
                    id: trayHoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                }

                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: Spacing.sm

                    Repeater {
                        model: root.trayService.items
                        
                        delegate: Item {
                            width: 18
                            height: 18
                            
                            property bool showTooltip: false
                            
                            Timer {
                                id: tooltipTimer
                                interval: 500
                                running: trayMouseArea.containsMouse && (modelData.tooltipTitle !== "" || modelData.title !== "")
                                onTriggered: showTooltip = true
                                onRunningChanged: {
                                    if (!running) {
                                        showTooltip = false
                                    }
                                }
                            }
                            
                            QsMenuAnchor {
                                id: trayMenuAnchor
                                menu: modelData.menu
                                anchor.window: bar
                                anchor.item: parent
                            }
                            
                            Image {
                                id: trayIconImage
                                anchors.fill: parent
                                source: modelData.icon || ""
                                fillMode: Image.PreserveAspectFit
                                cache: false
                                smooth: true
                                antialiasing: true
                            }
                            
                            MouseArea {
                                id: trayMouseArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onPressed: function(mouse) {
                                    console.log("[TRAY PRESS] pressed button:", mouse.button, "hasMenu:", modelData.hasMenu, "menu exists:", (modelData.menu !== null));
                                    if (mouse.button === Qt.RightButton) {
                                        if (modelData.hasMenu) {
                                            trayMenuAnchor.open()
                                            mouse.accepted = true
                                        } else {
                                            console.log("[TRAY PRESS] Fallback to display() method");
                                            try {
                                                modelData.display(bar, mouse.x, mouse.y);
                                                mouse.accepted = true;
                                            } catch (e) {
                                                console.log("[TRAY PRESS] display() failed:", e);
                                            }
                                        }
                                    }
                                }
                                
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        modelData.activate()
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        if (modelData.secondaryActivate) {
                                            modelData.secondaryActivate()
                                        } else {
                                            modelData.activate()
                                        }
                                    }
                                }
                                
                                onWheel: function(wheel) {
                                    var delta = wheel.angleDelta.y
                                    var horizontal = false
                                    if (delta === 0) {
                                        delta = wheel.angleDelta.x
                                        horizontal = true
                                    }
                                    if (modelData.scroll) {
                                        modelData.scroll(delta, horizontal)
                                    }
                                }
                            }

                            PopupWindow {
                                id: trayTooltipPopup
                                visible: showTooltip
                                
                                anchor {
                                    item: parent
                                    edges: Edges.Bottom
                                    gravity: Edges.Bottom
                                }
                                
                                color: "transparent"
                                width: tooltipRect.width
                                height: tooltipRect.height
                                
                                Rectangle {
                                    id: tooltipRect
                                    width: tooltipText.implicitWidth + 16
                                    height: tooltipText.implicitHeight + 8
                                    radius: Radius.small
                                    color: Qt.rgba(0, 0, 0, 0.85)
                                    border.color: root.walColor8
                                    border.width: 1
                                    
                                    Text {
                                        id: tooltipText
                                        anchors.centerIn: parent
                                        text: modelData.tooltipTitle || modelData.title || ""
                                        color: root.walForeground
                                        font.pixelSize: Typography.sizeSmall
                                        font.family: Typography.defaultFamily
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Notch {
                visible: root.batteryService.available
                width: visible ? (batteryRow.width + 24) : 0
                hovered: batteryMA.containsMouse
                tooltip: {
                    var t = bar.batteryPercent + "%"
                    if (bar.batteryCharging) t += " (Charging)"
                    if (bar.batteryTime) t += " - " + bar.batteryTime
                    return t
                }

                Item {
                    anchors.fill: parent

                    Row {
                        id: batteryRow
                        anchors.centerIn: parent
                        spacing: Spacing.sm

                        Item {
                            width: 20
                            height: 12
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: batteryBody
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 10
                                radius: 3
                                color: "transparent"
                                border.width: bar.batteryPercent >= 100 ? 0 : 1.5
                                border.color: {
                                    if (bar.batteryClass === "charging") return root.walColor2
                                    if (bar.batteryClass === "critical") return root.walColor1
                                    if (bar.batteryClass === "warning") return root.walColor4
                                    return root.walColor13
                                }
                                antialiasing: true

                                Behavior on border.color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    id: batteryFill
                                    anchors.left: parent.left
                                    anchors.leftMargin: bar.batteryPercent >= 100 ? 0 : 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: {
                                        if (bar.batteryPercent >= 100) return parent.width
                                        var base = Math.max(0, (parent.width - 5) * bar.batteryPercent / 100)
                                        if (bar.batteryCharging) {
                                            var extra = (parent.width - 5 - base) * bar.chargingFillAnim * 0.3
                                            return base + extra
                                        }
                                        return base
                                    }
                                    height: bar.batteryPercent >= 100 ? parent.height : parent.height - 4
                                    radius: bar.batteryPercent >= 100 ? 3 : 1.5
                                    color: {
                                        if (bar.batteryClass === "charging") return root.walColor2
                                        if (bar.batteryClass === "critical") return root.walColor1
                                        if (bar.batteryClass === "warning") return root.walColor4
                                        return root.walColor13
                                    }
                                    antialiasing: true

                                    Behavior on width { NumberAnimation { duration: bar.batteryCharging ? 50 : 600; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                }
                            }

                            Rectangle {
                                anchors.left: batteryBody.right
                                anchors.leftMargin: 1
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: 5
                                radius: 1
                                color: batteryFill.color
                                visible: bar.batteryPercent < 100
                                antialiasing: true

                                Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }

                            Text {
                                anchors.centerIn: batteryBody
                                text: Icons.batteryCharging
                                color: root.walBackground
                                font.pixelSize: Typography.sizeSuperTiny
                                font.family: Typography.defaultFamily
                                visible: bar.batteryCharging && bar.batteryPercent < 100
                                opacity: bar.chargingPulse
                            }

                            Text {
                                anchors.centerIn: batteryBody
                                text: Icons.check
                                color: root.walBackground
                                font.pixelSize: Typography.sizeTiny
                                font.family: Typography.defaultFamily
                                visible: bar.batteryPercent >= 100
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: bar.batteryPercent + "%"
                            color: batteryFill.color
                            font.pixelSize: Typography.sizeBodySmall
                            font.bold: true
                            font.family: Typography.defaultFamily

                            Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                MouseArea {
                    id: batteryMA
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            Notch {
                width: volumeLabel.implicitWidth + 24
                hovered: volumeMA.containsMouse
                tooltip: bar.volumeMuted ? "Muted" : (bar.volumePercent + "%")

                Item {
                    anchors.fill: parent

                    Text {
                        id: volumeLabel
                        anchors.centerIn: parent
                        text: bar.volumeStr
                        color: bar.volumeMuted ? root.walColor8 : "#89dceb"
                        font.pixelSize: Typography.sizeBodySmall
                        font.bold: true
                        font.family: Typography.defaultFamily

                        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                }

                MouseArea {
                    id: volumeMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.audioService.toggleMute()
                    onWheel: function(wheel) {
                        var delta = wheel.angleDelta.y > 0 ? 5 : -5
                        bar.adjustVolume(delta)
                    }
                }
            }

            Notch {
                width: networkRow.width + 24
                hovered: networkMA.containsMouse
                tooltip: {
                    var t = ""
                    if (bar.wifiConnected) t += bar.wifiSSID + " (" + bar.wifiStrength + "%)"
                    else t += "Not connected"
                    t += "\nBluetooth: " + (bar.btConnected ? "Connected" : "Off")
                    return t
                }

                Item {
                    anchors.fill: parent

                    Row {
                        id: networkRow
                        anchors.centerIn: parent
                        spacing: Spacing.sm

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (!bar.wifiConnected) return Icons.wifiSignal0
                                if (bar.wifiStrength > 75) return Icons.wifiSignal4
                                if (bar.wifiStrength > 50) return Icons.wifiSignal3
                                if (bar.wifiStrength > 25) return Icons.wifiSignal2
                                return Icons.wifiSignal1
                            }
                            color: bar.wifiConnected ? root.walColor2 : root.walColor8
                            font.pixelSize: Typography.sizeBodyLarge
                            font.family: Typography.defaultFamily

                            Behavior on color { ColorAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: bar.btConnected ? Icons.bluetoothConnected : Icons.bluetoothDisabled
                            color: bar.btConnected ? root.walColor5 : root.walColor8
                            font.pixelSize: Typography.sizeBodyMedium
                            font.family: Typography.defaultFamily

                            Behavior on color { ColorAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                MouseArea {
                    id: networkMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton)
                            root.toggleBluetooth()
                        else
                            root.toggleWifi()
                    }
                }
            }

            Notch {
                width: 36
                hovered: dashMA.containsMouse
                tooltip: "Dashboard"

                Item {
                    anchors.fill: parent

                    Text {
                        anchors.centerIn: parent
                        text: Icons.dashboard
                        color: root.walColor1
                        font.pixelSize: Typography.sizeNormalLarge
                        font.family: Typography.defaultFamily
                    }
                }

                MouseArea {
                    id: dashMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleDashboard()
                }
            }
        }
    }
}