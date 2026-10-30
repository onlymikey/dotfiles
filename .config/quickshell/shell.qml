//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "./components"
import "./services"
import "./theme"

ShellRoot {
    id: root

    property string homePath: String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace("file://", "")
    property string configPath: String(StandardPaths.writableLocation(StandardPaths.ConfigLocation)).replace("file://", "") + "/quickshell"
    property string wallpaperPath: homePath + "/wallpapers"
    property string cachePath: String(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)).replace("file://", "")
    property string statePath: configPath + "/state"

    property bool dashboardVisible: false
    property bool musicVisible: false
    property bool launcherVisible: false
    property bool wifiVisible: false
    property bool btVisible: false
    property bool notificationsVisible: false
    property bool calendarVisible: false
    property bool settingsVisible: false
    property int settingsTab: 0
    property bool phoneVisible: false
    property bool barForceVisible: false
    readonly property bool anyPanelOpen: dashboardVisible || musicVisible || launcherVisible || wifiVisible || btVisible || notificationsVisible || calendarVisible || settingsVisible || phoneVisible

    property var fullscreenByMonitor: ({})
    property string focusedMonitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property ShellScreen focusedScreen: {
        var monName = root.focusedMonitorName !== "" ? root.focusedMonitorName : (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
        if (monName !== "") {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === monName) {
                    return Quickshell.screens[i]
                }
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }
    readonly property ShellScreen barScreen: {
        var priName = (root.monitorService && root.monitorService.primaryMonitor) ? root.monitorService.primaryMonitor : ""
        if (priName !== "") {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === priName) {
                    return Quickshell.screens[i]
                }
            }
        }
        return root.focusedScreen ? root.focusedScreen : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    }
    property ShellScreen panelScreen: focusedScreen

    onFocusedScreenChanged: {
        if (!root.anyPanelOpen && root.focusedScreen) {
            root.panelScreen = root.focusedScreen
        }
    }

    function syncFullscreenState() {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
        if (!syncFullscreenProc.running) {
            syncFullscreenProc.running = true
        }
    }

    Process {
        id: syncFullscreenProc
        command: [
            "python3", "-c",
            "import os, socket, json\n" +
            "p = os.environ.get('XDG_RUNTIME_DIR', '') + '/hypr/' + os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '') + '/.socket.sock'\n" +
            "def req(cmd):\n" +
            "    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\n" +
            "    s.connect(p)\n" +
            "    s.sendall(cmd.encode())\n" +
            "    chunks = []\n" +
            "    while True:\n" +
            "        d = s.recv(8192)\n" +
            "        if not d: break\n" +
            "        chunks.append(d)\n" +
            "    s.close()\n" +
            "    return json.loads(b''.join(chunks).decode())\n" +
            "try:\n" +
            "    mons = req('j/monitors')\n" +
            "    workspaces = req('j/workspaces')\n" +
            "    clients = req('j/clients')\n" +
            "    fs_ws_names = set()\n" +
            "    for w in workspaces:\n" +
            "        if w.get('hasfullscreen'):\n" +
            "            fs_ws_names.add(w.get('name'))\n" +
            "    for c in clients:\n" +
            "        if c.get('mapped') and not c.get('hidden'):\n" +
            "            if c.get('fullscreen', 0) != 0 or c.get('fullscreenClient', 0) != 0:\n" +
            "                ws_name = c.get('workspace', {}).get('name')\n" +
            "                if ws_name: fs_ws_names.add(ws_name)\n" +
            "    out = {}\n" +
            "    for m in mons:\n" +
            "        m_name = m.get('name')\n" +
            "        aw_name = m.get('activeWorkspace', {}).get('name')\n" +
            "        sw_name = m.get('specialWorkspace', {}).get('name')\n" +
            "        is_fs = (aw_name in fs_ws_names) or (bool(sw_name) and sw_name in fs_ws_names)\n" +
            "        if not is_fs:\n" +
            "            for c in clients:\n" +
            "                if c.get('mapped') and not c.get('hidden') and c.get('monitor') == m.get('id'):\n" +
            "                    if c.get('fullscreen', 0) != 0 or c.get('fullscreenClient', 0) != 0:\n" +
            "                        c_ws = c.get('workspace', {}).get('name')\n" +
            "                        if c_ws in (aw_name, sw_name):\n" +
            "                            is_fs = True\n" +
            "                            break\n" +
            "        out[m_name] = bool(is_fs)\n" +
            "    print(json.dumps(out))\n" +
            "except Exception:\n" +
            "    print('{}')\n"
        ]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                try {
                    var parsed = JSON.parse(line)
                    root.fullscreenByMonitor = parsed
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name !== "") {
                root.focusedMonitorName = Hyprland.focusedMonitor.name
            }
        }
        function onRawEvent(event) {
            if (event.name === "focusedmon" || event.name === "focusedmonv2") {
                var parts = event.data.split(",")
                if (parts.length >= 1 && parts[0].trim() !== "") {
                    root.focusedMonitorName = parts[0].trim()
                }
                root.syncFullscreenState()
            } else if (event.name === "fullscreen") {
                var isFs = event.data.trim() !== "0" && event.data.trim() !== ""
                var monName = root.focusedMonitorName !== "" ? root.focusedMonitorName : (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "DP-3")
                var updated = {}
                for (var k in root.fullscreenByMonitor) {
                    updated[k] = root.fullscreenByMonitor[k]
                }
                updated[monName] = isFs
                root.fullscreenByMonitor = updated
                if (isFs && root.anyPanelOpen) {
                    root.panelManager.closeAll()
                }
                if (!isFs) {
                    root.barForceVisible = false
                }
                root.syncFullscreenState()
            } else if (event.name === "workspace" || event.name === "workspacev2" || event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindow" || event.name === "movewindowv2" || event.name === "activewindow" || event.name === "activewindowv2") {
                root.syncFullscreenState()
            } else if (event.name === "monitoradded" || event.name === "monitoraddedv2" || event.name === "monitorremoved" || event.name === "monitorremovedv2") {
                barRecreateTimer.restart()
                root.syncFullscreenState()
            }
        }
    }

    Timer {
        id: barRecreateTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (Quickshell.screens.length > 0) {
                barLoader.active = false
                barLoader.active = true
            }
        }
    }

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
    property alias brightnessService: brightnessServiceObj
    property alias monitorService: monitorServiceObj
    property alias settingsService: settingsServiceObj
    property alias phoneService: phoneServiceObj

    PhoneService {
        id: phoneServiceObj
    }

    SettingsService {
        id: settingsServiceObj
    }

    MonitorService {
        id: monitorServiceObj
    }

    BatteryService {
        id: batteryServiceObj
        pollingEnabled: true
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

    BrightnessService {
        id: brightnessServiceObj
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
        root.syncFullscreenState()
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
            loadDndProc.running = true
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
        id: loadDndProc
        command: ["bash", "-c", "cat '" + root.statePath + "/dnd' 2>/dev/null || echo 'false'"]
        stdout: SplitParser {
            onRead: data => {
                var dndVal = data.trim() === "true"
                root.notificationService.dnd = dndVal
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

        p.command = [
            "bash",
            "-lc",
            "setsid " + execStr + " >/dev/null 2>&1 &"
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
        command: ["python3", root.configPath + "/services/parse_apps.py"]
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

    Process {
        id: appWatcherProc
        command: ["python3", String(StandardPaths.writableLocation(StandardPaths.ConfigLocation)).replace("file://", "") + "/quickshell/services/parse_apps_watcher.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "change") {
                    console.log("APPS_WATCHER: Detected change, reloading launcher application list...")
                    root.reloadApps()
                }
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
            || root.calendarVisible
            || root.settingsVisible

    windows: [ wifiPanel, btPanel, launcherPanel, dashboardPanel, musicPanel, notificationCenter, notificationPopups, calendarPanel, settingsPanel ]
}

    Loader {
        id: barLoader
        active: Quickshell.screens.length > 0
        sourceComponent: Component {
            Bar {}
        }
    }
    Dashboard { id: dashboardPanel }
    MusicPanel { id: musicPanel }
    WifiPanel { id: wifiPanel }
    BluetoothPanel { id: btPanel }
    LauncherPanel { id: launcherPanel }
    NotificationCenter { id: notificationCenter }
    NotificationPopups { id: notificationPopups }
    CalendarPanel { id: calendarPanel }
    SettingsPanel { id: settingsPanel; activeTab: root.settingsTab }
    PhonePanel { id: phonePanel }



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
        target: "monitors"

        function toggle() {
            root.panelManager.toggle("settings", { tab: 0 })
        }
    }

    IpcHandler {
        target: "settings"

        function toggle() {
            root.panelManager.toggle("settings")
        }
    }

    IpcHandler {
        target: "phone"

        function toggle() {
            root.panelManager.toggle("phone")
        }

        function scrcpy() {
            if (root.phoneService) root.phoneService.toggleScrcpy()
        }

        function ring() {
            if (root.phoneService) root.phoneService.ringPhone()
        }
    }

    IpcHandler {
        target: "bar"

        function toggle() {
            root.barForceVisible = !root.barForceVisible
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
