import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: service

    // Volume & Mute properties for the default output device
    property int volume: 50
    property bool muted: false

    // Volume & Mute properties for the default input device
    property int sourceVolume: 50
    property bool sourceMuted: false

    // Available devices
    property var outputs: []
    property var inputs: []

    // Current default devices (objects containing id, name, and isDefault)
    property var defaultOutput: null
    property var defaultInput: null

    // Controls whether background polling is active
    property bool pollingEnabled: true

    function refresh() {
        if (!audioPollProc.running) {
            audioPollProc.running = true
        }
    }

    function setVolume(percent) {
        percent = Math.max(0, Math.min(100, percent))
        console.log("AUDIO_SERVICE_SET_VOLUME: percent=" + percent)
        service.volume = percent // Optimistic update
        var val = (percent / 100).toFixed(2)
        if (setVolumeProc.running) {
            setVolumeProc.running = false
        }
        setVolumeProc.command = ["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + val]
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
        percent = Math.max(0, Math.min(100, percent))
        console.log("AUDIO_SERVICE_SET_SOURCE_VOLUME: percent=" + percent)
        service.sourceVolume = percent // Optimistic update
        var val = (percent / 100).toFixed(2)
        if (setSourceVolumeProc.running) {
            setSourceVolumeProc.running = false
        }
        setSourceVolumeProc.command = ["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + val]
        setSourceVolumeProc.running = true
    }

    function toggleSourceMute() {
        service.sourceMuted = !service.sourceMuted // Optimistic update
        if (toggleSourceMuteProc.running) {
            toggleSourceMuteProc.running = false
        }
        toggleSourceMuteProc.running = true
    }

    function setOutput(deviceOrId) {
        var id = typeof deviceOrId === 'object' ? deviceOrId.id : deviceOrId
        if (setDefaultProc.running) {
            setDefaultProc.running = false
        }
        setDefaultProc.command = ["bash", "-c", "wpctl set-default " + String(id)]
        setDefaultProc.running = true
    }

    function setInput(deviceOrId) {
        var id = typeof deviceOrId === 'object' ? deviceOrId.id : deviceOrId
        if (setDefaultProc.running) {
            setDefaultProc.running = false
        }
        setDefaultProc.command = ["bash", "-c", "wpctl set-default " + String(id)]
        setDefaultProc.running = true
    }

    Process {
        id: setVolumeProc
        onExited: {
            console.log("setVolumeProc exited with code: " + exitCode + " status: " + exitStatus)
            service.refresh()
        }
        stderr: SplitParser {
            onRead: data => console.warn("setVolumeProc stderr: " + data.trim())
        }
    }

    Process {
        id: setSourceVolumeProc
        onExited: {
            console.log("setSourceVolumeProc exited with code: " + exitCode + " status: " + exitStatus)
            service.refresh()
        }
        stderr: SplitParser {
            onRead: data => console.warn("setSourceVolumeProc stderr: " + data.trim())
        }
    }

    Process {
        id: toggleMuteProc
        command: ["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"]
        onExited: {
            console.log("toggleMuteProc exited with code: " + exitCode + " status: " + exitStatus)
            service.refresh()
        }
        stderr: SplitParser {
            onRead: data => console.warn("toggleMuteProc stderr: " + data.trim())
        }
    }

    Process {
        id: toggleSourceMuteProc
        command: ["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"]
        onExited: {
            console.log("toggleSourceMuteProc exited with code: " + exitCode + " status: " + exitStatus)
            service.refresh()
        }
        stderr: SplitParser {
            onRead: data => console.warn("toggleSourceMuteProc stderr: " + data.trim())
        }
    }

    Process {
        id: setDefaultProc
        onExited: {
            console.log("setDefaultProc exited with code: " + exitCode + " status: " + exitStatus)
            service.refresh()
        }
        stderr: SplitParser {
            onRead: data => console.warn("setDefaultProc stderr: " + data.trim())
        }
    }

    Process {
        id: audioPollProc
        command: ["python3", "/home/mikey/.config/quickshell/services/parse_audio.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var state = JSON.parse(data.trim())
                    console.log("AUDIO_SERVICE_POLL: volume=" + state.volume + " muted=" + state.muted + " srcVolume=" + state.sourceVolume + " srcMuted=" + state.sourceMuted)
                    service.volume = state.volume
                    service.muted = state.muted
                    service.sourceVolume = state.sourceVolume
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
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 2000
        running: service.pollingEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refresh()
    }
}
