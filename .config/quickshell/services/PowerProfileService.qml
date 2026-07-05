import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: service

    // Reactive properties as requested
    property bool supported: false
    property string backendName: "None"
    property string currentProfile: ""
    property var availableProfiles: []
    property string driver: ""

    // Spawns/restarts the backend process if not already running
    function refresh() {
        if (!powerServiceProc.running) {
            powerServiceProc.running = true
        } else {
            powerServiceProc.write("refresh\n")
        }
    }

    // Set the power profile
    function setProfile(profile) {
        if (powerServiceProc.running) {
            powerServiceProc.write("set_profile|" + profile + "\n")
        }
    }

    // Persistent Python subprocess querying power profiles
    Process {
        id: powerServiceProc
        command: ["python3", "/home/mikey/.config/quickshell/services/parse_power.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var state = JSON.parse(data.trim())
                    service.supported = state.supported
                    service.backendName = state.backendName
                    service.currentProfile = state.currentProfile
                    service.availableProfiles = state.availableProfiles
                    service.driver = state.driver
                } catch (e) {
                    console.warn("Error parsing Power Profile JSON: " + e)
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("PowerProfileService backend stderr: " + data.trim())
        }
    }

    Component.onCompleted: refresh()
}
