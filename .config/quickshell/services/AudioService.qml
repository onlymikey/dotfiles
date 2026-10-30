import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

Item {
    id: service

    // Volume & Mute properties for the default output device
    property int volume: 50
    property bool muted: false

    // Overamplification (up to 150%)
    property bool overamplification: false
    property bool boostLoaded: false
    property int maxVolume: overamplification ? 150 : 100

    // Volume & Mute properties for the default input device
    property int sourceVolume: 50
    property bool sourceMuted: false

    // Available devices
    property var outputs: []
    property var inputs: []

    // Current default devices (objects containing id, name, and isDefault)
    property var defaultOutput: null
    property var defaultInput: null

    // Kept for backward compatibility with shell.qml bindings
    property bool pollingEnabled: true

    property string configDir: String(StandardPaths.writableLocation(StandardPaths.ConfigLocation)).replace("file://", "") + "/quickshell"
    property string boostStateFile: configDir + "/state/volume_boost"

    function refresh() {
        if (!audioPollProc.running) {
            audioPollProc.running = true
        } else {
            audioPollProc.write("refresh\n")
        }
    }

    function setOveramplification(enabled) {
        service.overamplification = enabled
        saveBoostProc.command = ["bash", "-c", "mkdir -p '" + configDir + "/state' && echo '" + (enabled ? "true" : "false") + "' > '" + boostStateFile + "'"]
        saveBoostProc.running = true
        if (!enabled && service.volume > 100) {
            setVolume(100)
        }
    }

    function toggleOveramplification() {
        setOveramplification(!service.overamplification)
    }

    property int pendingVolume: -1
    property int pendingSourceVolume: -1

    function setVolume(percent) {
        var maxV = service.maxVolume
        percent = Math.max(0, Math.min(maxV, Math.round(percent)))
        service.volume = percent // Optimistic update
        service.pendingVolume = percent
        if (!setVolumeProc.running) {
            runNextVolume()
        }
    }

    function runNextVolume() {
        if (service.pendingVolume < 0) return
        var percent = service.pendingVolume
        service.pendingVolume = -1
        var val = (percent / 100).toFixed(2)
        var limit = service.overamplification ? "1.5" : "1.0"
        setVolumeProc.command = ["wpctl", "set-volume", "-l", limit, "@DEFAULT_AUDIO_SINK@", String(val)]
        setVolumeProc.running = true
    }

    function toggleMute() {
        service.muted = !service.muted // Optimistic update
        if (toggleMuteProc.running) {
            toggleMuteProc.running = false
        }
        toggleMuteProc.running = true
    }

    function setSourceVolume(percent) {
        percent = Math.max(0, Math.min(100, Math.round(percent)))
        service.sourceVolume = percent // Optimistic update
        service.pendingSourceVolume = percent
        if (!setSourceVolumeProc.running) {
            runNextSourceVolume()
        }
    }

    function runNextSourceVolume() {
        if (service.pendingSourceVolume < 0) return
        var percent = service.pendingSourceVolume
        service.pendingSourceVolume = -1
        var val = (percent / 100).toFixed(2)
        setSourceVolumeProc.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SOURCE@", String(val)]
        setSourceVolumeProc.running = true
    }

    function toggleSourceMute() {
        service.sourceMuted = !service.sourceMuted // Optimistic update
        if (toggleSourceMuteProc.running) {
            toggleSourceMuteProc.running = false
        }
        toggleSourceMuteProc.running = true
    }

    function buildSwitchCommand(deviceOrId, isInput) {
        var id = typeof deviceOrId === 'object' ? String(deviceOrId.id) : String(deviceOrId)
        var nodeName = (typeof deviceOrId === 'object' && deviceOrId.nodeName) ? String(deviceOrId.nodeName) : ""
        if (id.indexOf("card:") === 0) {
            var parts = id.split(":")
            var cardId = parts[1]
            var profIdx = parts[2]
            return "wpctl set-profile " + cardId + " " + profIdx + " && sleep 0.35 && " +
                   "new_id=$(pw-dump | python3 -c \"import sys,json; data=json.load(sys.stdin); print(next((str(x['id']) for x in data if x.get('type')=='PipeWire:Interface:Node' and (x.get('info',{}).get('props',{}).get('device.id')==" + cardId + ") and '" + (isInput ? "Source" : "Sink") + "' in (x.get('info',{}).get('props',{}).get('media.class',''))), ''))\" 2>/dev/null); " +
                   "[ -n \"$new_id\" ] && wpctl set-default \"$new_id\""
        }
        var cmd = "wpctl set-default " + id
        if (!isInput && nodeName !== "") {
            cmd += "; pactl set-default-sink '" + nodeName + "' 2>/dev/null; for si in $(pactl list short sink-inputs 2>/dev/null | cut -f1); do pactl move-sink-input \"$si\" '" + nodeName + "' 2>/dev/null; done"
        } else if (isInput && nodeName !== "") {
            cmd += "; pactl set-default-source '" + nodeName + "' 2>/dev/null"
        }
        return cmd
    }

    function setOutput(deviceOrId) {
        if (setDefaultProc.running) {
            setDefaultProc.running = false
        }
        setDefaultProc.command = ["bash", "-c", buildSwitchCommand(deviceOrId, false)]
        setDefaultProc.running = true
    }

    function setInput(deviceOrId) {
        if (setDefaultProc.running) {
            setDefaultProc.running = false
        }
        setDefaultProc.command = ["bash", "-c", buildSwitchCommand(deviceOrId, true)]
        setDefaultProc.running = true
    }

    Process {
        id: loadBoostProc
        command: ["bash", "-c", "cat '" + service.boostStateFile + "' 2>/dev/null || echo 'false'"]
        stdout: SplitParser {
            onRead: data => {
                service.overamplification = (data.trim() === "true")
                service.boostLoaded = true
                if (!service.overamplification && service.volume > 100) {
                    service.setVolume(100)
                }
            }
        }
    }

    Process {
        id: saveBoostProc
    }

    Process {
        id: setVolumeProc
        onExited: {
            if (service.pendingVolume >= 0) {
                service.runNextVolume()
            } else {
                service.refresh()
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("setVolumeProc stderr: " + data.trim())
        }
    }

    Process {
        id: setSourceVolumeProc
        onExited: {
            if (service.pendingSourceVolume >= 0) {
                service.runNextSourceVolume()
            } else {
                service.refresh()
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("setSourceVolumeProc stderr: " + data.trim())
        }
    }

    Process {
        id: toggleMuteProc
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onExited: service.refresh()
        stderr: SplitParser {
            onRead: data => console.warn("toggleMuteProc stderr: " + data.trim())
        }
    }

    Process {
        id: toggleSourceMuteProc
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
        onExited: service.refresh()
        stderr: SplitParser {
            onRead: data => console.warn("toggleSourceMuteProc stderr: " + data.trim())
        }
    }

    Process {
        id: setDefaultProc
        onExited: service.refresh()
        stderr: SplitParser {
            onRead: data => console.warn("setDefaultProc stderr: " + data.trim())
        }
    }

    Process {
        id: audioPollProc
        command: ["python3", service.configDir + "/services/parse_audio.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var state = JSON.parse(data.trim())
                    if (service.boostLoaded && !service.overamplification && state.volume > 100) {
                        service.setVolume(100)
                    } else if (service.pendingVolume < 0 && !setVolumeProc.running) {
                        service.volume = state.volume
                    }
                    service.muted = state.muted
                    if (service.pendingSourceVolume < 0 && !setSourceVolumeProc.running) {
                        service.sourceVolume = state.sourceVolume
                    }
                    service.sourceMuted = state.sourceMuted
                    service.outputs = state.outputs
                    service.inputs = state.inputs

                    var defOut = null
                    for (var i = 0; i < state.outputs.length; i++) {
                        if (state.outputs[i].isDefault) {
                            defOut = state.outputs[i]
                            break
                        }
                    }
                    service.defaultOutput = defOut

                    var defIn = null
                    for (var j = 0; j < state.inputs.length; j++) {
                        if (state.inputs[j].isDefault) {
                            defIn = state.inputs[j]
                            break
                        }
                    }
                    service.defaultInput = defIn
                } catch (e) {
                    console.warn("Error parsing audio JSON: " + e)
                }
            }
        }
        onExited: {
            restartTimer.start()
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!audioPollProc.running) {
                audioPollProc.running = true
            }
        }
    }

    Component.onCompleted: {
        loadBoostProc.running = true
        if (!audioPollProc.running) {
            audioPollProc.running = true
        }
    }
}
