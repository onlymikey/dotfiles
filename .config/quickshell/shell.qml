//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "./components"
import "./services"

ShellRoot {
    id: root

    property string configPath: Quickshell.env("HOME") + "/.config/quickshell"
    property string homePath: Quickshell.env("HOME")
    property string wallpaperPath: homePath + "/wallpapers"
    property string cachePath: homePath + "/.cache"
    property string statePath: configPath + "/state"

    property bool dashboardVisible: false
    property bool musicVisible: false
    property bool launcherVisible: false
    property bool wifiVisible: false
    property bool btVisible: false
    property bool notificationsVisible: false
    property bool calendarVisible: false
    property var pfpFiles: []
    property string searchTerm: ""
    property var appList: []
    property var appUsage: ({})
    property var filteredApps: {
        var source = appList
        var usage = appUsage
        if (searchTerm !== "") {
            var result = []
            for (var i = 0; i < source.length; i++) {
                var entry = source[i]
                if (entry.name.toLowerCase().includes(searchTerm) || entry.exec.toLowerCase().includes(searchTerm)) {
                    result.push(entry)
                }
            }
            source = result
        }
        var sorted = source.slice().sort(function(a, b) {
            var countA = usage[a.name] || 0
            var countB = usage[b.name] || 0
            if (countB !== countA) return countB - countA
            return a.name.localeCompare(b.name)
        })
        return sorted
    }
    property int selectedIndex: 0
    property int activeTab: 0
    property string wallSearchTerm: ""
    property var wallpaperList: []
    property var filteredWallpapers: {
        if (wallSearchTerm === "") return wallpaperList
        var result = []
        for (var i = 0; i < wallpaperList.length; i++) {
            if (wallpaperList[i].name.toLowerCase().includes(wallSearchTerm)) {
                result.push(wallpaperList[i])
            }
        }
        return result
    }
    property int wallSelectedIndex: 0
    property string currentWallpaper: ""
    property bool wallsLoaded: false
    property bool thumbsReady: false
    property bool walApplying: false

    property alias networkService: networkServiceObj
    property alias wifiEnabled: networkServiceObj.wifiEnabled
    property string wifiCurrentSSID: networkServiceObj.connectedNetwork ? networkServiceObj.connectedNetwork.ssid : ""
    property int wifiSignal: networkServiceObj.connectedNetwork ? networkServiceObj.connectedNetwork.signal : 0
    property alias wifiNetworks: networkServiceObj.availableNetworks
    property alias wifiScanning: networkServiceObj.wifiScanning
    property bool wifiConnecting: false

    property alias bluetoothService: bluetoothServiceObj
    property alias btEnabled: bluetoothServiceObj.enabled
    property alias btScanning: bluetoothServiceObj.scanning
    property alias btConnectingMAC: bluetoothServiceObj.connectingMac
    property alias btPairedDevices: bluetoothServiceObj.pairedDevices
    property alias btAvailableDevices: bluetoothServiceObj.availableDevices

    property color walBackground: "#1e1e2e"
    property color walForeground: "#cdd6f4"
    property color walColor1: "#f38ba8"
    property color walColor2: "#a6e3a1"
    property color walColor4: "#f9e2af"
    property color walColor5: "#89b4fa"
    property color walColor8: "#6c7086"
    property color walColor13: "#f5c2e7"

    property int savedGifIndex: 0

    property var clipboardHistory: []
    property int clipboardSelectedIndex: 0
    property string clipboardSearchTerm: ""
    property var filteredClipboardHistory: clipboardHistory.filter(item =>
    item.text.toLowerCase().includes(clipboardSearchTerm)
)

    property alias batteryService: batteryServiceObj
    property alias audioService: audioServiceObj
    property alias panelManager: panelManagerObj
    property alias trayService: trayServiceObj
    property alias notificationService: notificationServiceObj
    property alias powerProfileService: powerProfileServiceObj
    property alias sensorService: sensorServiceObj
    property alias calendarService: calendarServiceObj

    BatteryService {
        id: batteryServiceObj
        pollingEnabled: root.dashboardVisible
    }

    AudioService {
        id: audioServiceObj
        pollingEnabled: true
    }

    BluetoothService {
        id: bluetoothServiceObj
    }

    NetworkService {
        id: networkServiceObj
    }

    TrayService {
        id: trayServiceObj
    }

    NotificationService {
        id: notificationServiceObj
    }

    PowerProfileService {
        id: powerProfileServiceObj
    }

    SensorService {
        id: sensorServiceObj
        pollingEnabled: root.dashboardVisible
    }

    CalendarService {
        id: calendarServiceObj
    }

    PanelManager {
        id: panelManagerObj
        shell: root
    }


    function reloadApps() {
    if (!appListProc.running)
        appListProc.running = true
}

    function toggleLauncher() {
        panelManager.toggle("launcher", { tab: 0 })
    }

    function toggleDashboard() {
        panelManager.toggle("dashboard")
    }

    function toggleMusic() {
        panelManager.toggle("music")
    }

    function toggleWifi() {
        panelManager.toggle("wifi")
    }

    function toggleBluetooth() {
        panelManager.toggle("bluetooth")
    }

    function closeAllPanels() {
        panelManager.closeAll()
    }

    function refreshBluetooth() {
        bluetoothService.startDiscovery()
    }

    function connectBt(mac) {
        bluetoothService.connectDevice(mac)
    }

    function disconnectBt(mac) {
        bluetoothService.disconnectDevice(mac)
    }

    function pairBt(mac) {
        bluetoothService.pairDevice(mac)
    }

    function forgetBt(mac) {
        bluetoothService.forgetDevice(mac)
    }

    function refreshWifi() {
        networkService.scan()
    }

    

    function saveState(key, value) {
        saveStateProc.command = ["bash", "-c", "mkdir -p '" + statePath + "' && echo '" + value + "' > '" + statePath + "/" + key + "'"]
        saveStateProc.running = true
    }

    function loadState(key, callback) {
        loadStateProc.stateKey = key
        loadStateProc.callback = callback
        loadStateProc.command = ["cat", statePath + "/" + key]
        loadStateProc.running = true
    }

    Component.onCompleted: {
        initStateDir.running = true
    }

    Process {
        id: initStateDir
        command: ["mkdir", "-p", root.statePath]
        onExited: {
            walColorsProc.running = true
            appListProc.running = true
            loadUsageProc.running = true
            currentWallProc.running = true
            thumbDirProc.running = true
            loadGifIndexProc.running = true
        }
    }

    Process {
        id: loadGifIndexProc
        command: ["bash", "-c", "cat '" + root.statePath + "/gif-index' 2>/dev/null || echo '0'"]
        stdout: SplitParser {
            onRead: data => {
                var idx = parseInt(data.trim())
                root.savedGifIndex = isNaN(idx) ? 0 : idx
            }
        }
    }

    Process {
        id: saveStateProc
    }

    Process {
        id: loadStateProc
        property string stateKey: ""
        property var callback: null
        stdout: SplitParser {
            onRead: data => {
                if (loadStateProc.callback) {
                    loadStateProc.callback(data.trim())
                }
            }
        }
    }

    Process {
    id: clipboardProc

    command: ["bash", "-lc", "cliphist list | head -100"]

    stdout: SplitParser {
        onRead: data => {
            var line = data.trim()

            if (line.length === 0)
                return

            var parts = line.split("\t")

            if (parts.length < 2)
                return

            var current = root.clipboardHistory.slice()

            current.push({
                id: parts[0],
                text: parts.slice(1).join("\t")
            })

            root.clipboardHistory = current
        }
    }
}

function reloadClipboard() {
    root.clipboardHistory = []

    if (!clipboardProc.running)
        clipboardProc.running = true
}

    function launchApp(app) {
    var execStr = (app.exec || "").trim()
    if (execStr.length === 0) return

    // 1) Close the launcher first to release layer keyboard focus (hog)
    root.panelManager.close("launcher")

    // 2) Launch on next tick so Hyprland can re-evaluate focus cleanly
    Qt.callLater(function() {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root, 'launchProcDyn')

        // Escape quotes to keep hyprctl happy
        var safe = execStr.replace(/"/g, '\\"')

        // Launch via Hyprland (same semantics as hyprland keybind exec -> focus works)
        p.command = [
            "bash",
            "-lc",
            "setsid " + safe + " >/dev/null 2>&1 &"
        ]
        p.running = true
        p.exited.connect(function() { p.destroy() })
    })

    // usage tracking (same logic you already have)
    var usage = appUsage
    var updated = {}
    for (var key in usage) updated[key] = usage[key]
    updated[app.name] = (updated[app.name] || 0) + 1
    appUsage = updated
    saveUsageProc.command = ["bash", "-lc",
        "echo '" + JSON.stringify(updated) + "' > '" + root.configPath + "/app_usage.json'"
    ]
    saveUsageProc.running = true
}

    function restoreClipboard(item) {
    launchProc.command = [
        "bash",
        "-lc",
        "cliphist decode " + item.id + " | wl-copy"
    ]

    launchProc.running = true

    panelManager.close("launcher")
}

    function applyWallpaper(wallpaper) {
        root.currentWallpaper = wallpaper.path
        root.walApplying = true
        applyWallProc.command = ["bash", "-c",
            "ln -sf '" + wallpaper.path + "' '" + root.wallpaperPath + "/current' && " +
            "awww img '" + wallpaper.path + "' --transition-type any --transition-duration 2 & " +
            "wal -i '" + wallpaper.path + "' -n -q && " +
            "sleep 0.3"
        ]
        applyWallProc.running = true
    }

    function loadWallpapers() {
        root.wallpaperList = []
        root.wallsLoaded = false
        root.thumbsReady = false
        if (!wallpaperListProc.running) wallpaperListProc.running = true
    }

    Process {
        id: thumbDirProc
        command: ["mkdir", "-p", root.cachePath + "/wallpaper-thumbs"]
        onExited: root.loadWallpapers()
    }

    Process {
        id: wallpaperListProc
        command: ["bash", "-c", "find '" + root.wallpaperPath + "' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.png' -o -iname '*.webp' \\) ! -name '.*' 2>/dev/null | sort | while read -r f; do hash=$(echo -n \"$f\" | md5sum | cut -d' ' -f1); echo \"$f|$hash\"; done"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                var parts = line.split("|")
                var path = parts[0]
                var hash = parts.length > 1 ? parts[1] : ""
                var nameParts = path.split("/")
                var name = nameParts[nameParts.length - 1]
                var current = root.wallpaperList.slice()
                current.push({ name: name, path: path, hash: hash })
                root.wallpaperList = current
            }
        }
        onExited: {
            root.wallsLoaded = true
            if (!thumbGenProc.running) thumbGenProc.running = true
        }
    }

    Process {
        id: thumbGenProc
        command: ["bash", "-c",
            "THUMB_DIR='" + root.cachePath + "/wallpaper-thumbs' && " +
            "WALL_DIR='" + root.wallpaperPath + "' && " +
            "cd \"$THUMB_DIR\" && " +
            "find \"$WALL_DIR\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.png' -o -iname '*.webp' \\) ! -name '.*' 2>/dev/null | " +
            "while IFS= read -r f; do " +
            "  hash=$(echo -n \"$f\" | md5sum | cut -d' ' -f1); " +
            "  thumb=\"$THUMB_DIR/${hash}.jpg\"; " +
            "  if [ ! -f \"$thumb\" ] || [ \"$f\" -nt \"$thumb\" ]; then " +
            "    if command -v vipsthumbnail >/dev/null 2>&1; then " +
            "      case \"$f\" in " +
            "        *.gif) convert \"${f}[0]\" -thumbnail 180x120^ -gravity center -extent 180x120 -quality 85 \"$thumb\" 2>/dev/null ;; " +
            "        *) vipsthumbnail \"$f\" -s 180x120 -o \"$thumb\" 2>/dev/null || convert \"$f\" -thumbnail 180x120^ -gravity center -extent 180x120 -quality 85 \"$thumb\" 2>/dev/null ;; " +
            "      esac; " +
            "    else " +
            "      case \"$f\" in " +
            "        *.gif) convert \"${f}[0]\" -thumbnail 180x120^ -gravity center -extent 180x120 -quality 85 \"$thumb\" 2>/dev/null ;; " +
            "        *) convert \"$f\" -thumbnail 180x120^ -gravity center -extent 180x120 -quality 85 \"$thumb\" 2>/dev/null ;; " +
            "      esac; " +
            "    fi; " +
            "  fi; " +
            "done"
        ]
        onExited: root.thumbsReady = true
    }

    Process {
        id: applyWallProc
        onExited: {
            if (!walColorsProc.running) walColorsProc.running = true
        }
    }

    Process {
        id: walColorsProc
        command: ["bash", "-c", "cat '" + root.cachePath + "/wal/colors.json' 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var json = JSON.parse(data)
                    if (json.special) {
                        root.walBackground = json.special.background || root.walBackground
                        root.walForeground = json.special.foreground || root.walForeground
                    }
                    if (json.colors) {
                        root.walColor1 = json.colors.color1 || root.walColor1
                        root.walColor2 = json.colors.color2 || root.walColor2
                        root.walColor4 = json.colors.color4 || root.walColor4
                        root.walColor5 = json.colors.color5 || root.walColor5
                        root.walColor8 = json.colors.color8 || root.walColor8
                        root.walColor13 = json.colors.color13 || root.walColor13
                    }
                } catch(e) {}
            }
        }
        onExited: {
            if (root.walApplying) {
                if (!walStepSwaync.running) walStepSwaync.running = true
            }
        }
    }

    Process {
        id: walStepSwaync
        command: ["bash", "-c", "cp '" + root.cachePath + "/wal/colors-swaync.css' '" + root.configPath + "/../swaync/style.css' 2>/dev/null; pkill -SIGUSR1 swaync 2>/dev/null"]
        onExited: {
            if (!walStepBlur.running) walStepBlur.running = true
        }
    }

    Process {
        id: walStepBlur
        command: {
            var wp = root.currentWallpaper
            if (wp.endsWith(".gif"))
                return ["bash", "-c", "convert '" + wp + "[0]' -resize 1920x -blur 0x8 -quality 85 '" + root.wallpaperPath + "/.current-blurred.jpg' 2>/dev/null"]
            else
                return ["bash", "-c", "convert '" + wp + "' -resize 1920x -blur 0x8 -quality 85 '" + root.wallpaperPath + "/.current-blurred.jpg' 2>/dev/null"]
        }
        onExited: root.walApplying = false
    }

    Process {
        id: currentWallProc
        command: ["bash", "-c", "readlink -f '" + root.wallpaperPath + "/current' 2>/dev/null || echo ''"]
        stdout: SplitParser { onRead: data => root.currentWallpaper = data.trim() }
    }

    Process {
        id: loadUsageProc
        command: ["bash", "-c", "cat '" + root.configPath + "/app_usage.json' 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try { root.appUsage = JSON.parse(data.trim()) } catch(e) { root.appUsage = {} }
            }
        }
    }

    Process { id: saveUsageProc }
    Process { id: launchProc }

    Process {
        id: appListProc
        onRunningChanged: {
        if (running)
            root.appList = []
    }
        command: ["bash", "-c",
            "for f in /usr/share/applications/*.desktop '" + root.homePath + "/.local/share/applications'/*.desktop; do " +
            "  [ -f \"$f\" ] || continue; " +
            "  grep -qi '^NoDisplay=true' \"$f\" && continue; " +
            "  grep -qi '^Hidden=true' \"$f\" && continue; " +
            "  name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "  exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[fFuUdDnNickvm]//g'); " +
            "  icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); " +
            "  [ -z \"$name\" ] && continue; " +
            "  [ -z \"$exec\" ] && continue; " +
            "  printf '%s\\t%s\\t%s\\n' \"$name\" \"$exec\" \"$icon\"; " +
            "done | sort -f -t$'\\t' -k1,1 | awk -F'\\t' '!seen[$1]++'"
        ]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                var parts = line.split("\t")
                if (parts.length < 2) return
                var current = root.appList.slice()
                current.push({ name: parts[0], exec: parts[1], icon: parts.length > 2 ? parts[2] : "" })
                root.appList = current
            }
        }
    }





HyprlandFocusGrab {
    active: root.wifiVisible
            || root.btVisible
            || root.launcherVisible
            || root.dashboardVisible
            || root.musicVisible
            || root.notificationsVisible

    windows: [ wifiPanel, btPanel, launcherPanel, dashboardPanel, musicPanel, notificationCenter, notificationPopups ]
}

    Bar {}
    Dashboard { id: dashboardPanel }
    MusicPanel { id: musicPanel }
    WifiPanel { id: wifiPanel }
    BluetoothPanel { id: btPanel }
    LauncherPanel { id: launcherPanel }
    NotificationCenter { id: notificationCenter }
    NotificationPopups { id: notificationPopups }
    CalendarPanel { id: calendarPanel }



    IpcHandler {
        target: "launcher"
        function toggle() {
            root.panelManager.toggle("launcher", { tab: 0 })
        }
    }
    IpcHandler {
        target: "dashboard"
        function toggle() {
            root.panelManager.toggle("dashboard")
        }
    }
    IpcHandler {
        target: "music"
        function toggle() {
            root.panelManager.toggle("music")
        }
    }
    IpcHandler {
        target: "wallpaper"
        function toggle() {
            root.panelManager.toggle("launcher", { tab: 1 })
        }
    }
    IpcHandler {
        target: "wifi"
        function toggle() {
            root.panelManager.toggle("wifi")
        }
    }
    IpcHandler {
        target: "bluetooth"
        function toggle() {
            root.panelManager.toggle("bluetooth")
        }
    }
    IpcHandler {
        target: "clipboard"

        function toggle() {
            root.panelManager.toggle("launcher", { tab: 2 })
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle() {
            root.panelManager.toggle("notifications")
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle() {
            root.panelManager.toggle("calendar")
        }
    }

    IpcHandler {
        target: "gestures"

        function trigger(gesture: string) {
            root.panelManager.handleGesture(gesture)
        }

        function swipe_up() {
            root.panelManager.handleGesture("swipe-up")
        }
        function swipe_down() {
            root.panelManager.handleGesture("swipe-down")
        }
        function four_up() {
            root.panelManager.handleGesture("four-up")
        }
        function four_down() {
            root.panelManager.handleGesture("four-down")
        }
        function four_left() {
            root.panelManager.handleGesture("four-left")
        }
        function four_right() {
            root.panelManager.handleGesture("four-right")
        }

        function swipeUp() {
            root.panelManager.handleGesture("swipe-up")
        }
        function swipeDown() {
            root.panelManager.handleGesture("swipe-down")
        }
        function fourUp() {
            root.panelManager.handleGesture("four-up")
        }
        function fourDown() {
            root.panelManager.handleGesture("four-down")
        }
        function fourLeft() {
            root.panelManager.handleGesture("four-left")
        }
        function fourRight() {
            root.panelManager.handleGesture("four-right")
        }
    }
}
