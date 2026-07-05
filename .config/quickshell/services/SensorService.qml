import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: service

    // Reactive telemetry properties
    property int cpuUsage: 0
    property int ramUsage: 0
    property int diskUsage: 0

    property var cpuTemperature: null
    property var gpuTemperature: null
    property var ssdTemperature: null
    property var fanSpeed: null
    property var cpuPower: null
    property var gpuPower: null
    
    property var availableSensors: []

    // Controls polling from outside (e.g. tie to panel visibility)
    property bool pollingEnabled: true

    Process {
        id: sensorServiceProc
        command: ["python3", "/home/mikey/.config/quickshell/services/parse_sensors.py"]
        running: service.pollingEnabled
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    var state = JSON.parse(data.trim())
                    service.cpuUsage = state.cpuUsage
                    service.ramUsage = state.ramUsage
                    service.diskUsage = state.diskUsage
                    
                    service.cpuTemperature = state.cpuTemperature
                    service.gpuTemperature = state.gpuTemperature
                    service.ssdTemperature = state.ssdTemperature
                    service.fanSpeed = state.fanSpeed
                    service.cpuPower = state.cpuPower
                    service.gpuPower = state.gpuPower
                    
                    service.availableSensors = state.availableSensors
                } catch (e) {
                    console.warn("Error parsing Sensor JSON: " + e)
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("SensorService backend stderr: " + data.trim())
        }
    }
}
