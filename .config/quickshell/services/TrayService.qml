import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Item {
    id: service

    // Expose the items model of the system tray singleton as a standard JS array
    property var items: SystemTray.items ? SystemTray.items.values : []

    // Expose the active tray icon count to dynamically toggle the notch visibility
    property int count: (SystemTray.items && SystemTray.items.values !== undefined) ? SystemTray.items.values.length : 0
}
