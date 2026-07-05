import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: service

    property bool dnd: false
    property int unreadCount: 0
    
    // Read-only alias to the history list model
    property alias history: historyModel

    // Signal emitted when a new notification should trigger a visual popup on screen
    signal notificationTriggered(int id, string appName, string summary, string body, string appIcon, string image, bool hasDefaultAction, var notifActions)

    // Store raw active C++ Notification objects to invoke actions or dismiss them
    property var activeNotifications: ({})

    ListModel {
        id: historyModel
    }

    NotificationServer {
        id: server
        keepOnReload: true
        
        // Advertise capabilities to notification clients
        bodyMarkupSupported: true
        actionsSupported: true

        onNotification: function(notification) {
            // Keep the notification alive on D-Bus so we can interact with it
            notification.tracked = true
            
            // Store active reference
            activeNotifications[notification.id] = notification
            
            // Listen for closed signal (app-requested close, timeout, etc.)
            notification.closed.connect(function(reason) {
                delete activeNotifications[notification.id]
                
                // When closed, we disable actions in history by clearing them
                var foundIdx = -1
                for (var idx = 0; idx < historyModel.count; idx++) {
                    if (historyModel.get(idx).id === notification.id) {
                        foundIdx = idx
                        break
                    }
                }
                if (foundIdx !== -1) {
                    historyModel.setProperty(foundIdx, "notifActions", [])
                }
            })

            // Parse actions list into JS array of primitives
            var actionsList = []
            var hasDefault = false
            if (notification.actions) {
                for (var i = 0; i < notification.actions.length; i++) {
                    if (notification.actions[i].identifier === "default") {
                        hasDefault = true
                    } else {
                        actionsList.push({
                            identifier: notification.actions[i].identifier,
                            text: notification.actions[i].text
                        })
                    }
                }
            }

            // Find if notification is already in history to replace it (updates summary/body)
            var foundIdx = -1
            for (var idx = 0; idx < historyModel.count; idx++) {
                if (historyModel.get(idx).id === notification.id) {
                    foundIdx = idx
                    break
                }
            }

            var notifData = {
                id: notification.id,
                appName: notification.appName || "Notification",
                summary: notification.summary || "",
                body: notification.body || "",
                appIcon: notification.appIcon || "",
                image: notification.image || "",
                urgency: notification.urgency,
                timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
                unread: true,
                hasDefaultAction: hasDefault,
                notifActions: actionsList
            }

            if (foundIdx !== -1) {
                // Update existing item
                historyModel.set(foundIdx, notifData)
            } else {
                // Insert at top (newest first)
                historyModel.insert(0, notifData)
            }

            updateUnreadCount()

            // Emit trigger signal for popups if Do Not Disturb is disabled
            if (!dnd && !notification.transient) {
                notificationTriggered(
                    notification.id,
                    notifData.appName,
                    notifData.summary,
                    notifData.body,
                    notifData.appIcon,
                    notifData.image,
                    hasDefault,
                    actionsList
                )
            }
        }
    }

    function toggleDnd() {
        dnd = !dnd
    }

    function clearNotification(id) {
        // If active, dismiss it first
        var activeNotif = activeNotifications[id]
        if (activeNotif) {
            activeNotif.dismiss()
        }

        // Remove from history list model
        for (var idx = 0; idx < historyModel.count; idx++) {
            if (historyModel.get(idx).id === id) {
                historyModel.remove(idx)
                break
            }
        }
        updateUnreadCount()
    }

    function clearAll() {
        // Dismiss all active notifications
        for (var key in activeNotifications) {
            if (activeNotifications.hasOwnProperty(key)) {
                activeNotifications[key].dismiss()
            }
        }
        activeNotifications = {}

        // Clear history
        historyModel.clear()
        updateUnreadCount()
    }

    function invokeAction(id, identifier) {
        var activeNotif = activeNotifications[id]
        if (activeNotif && activeNotif.actions) {
            for (var i = 0; i < activeNotif.actions.length; i++) {
                if (activeNotif.actions[i].identifier === identifier) {
                    activeNotif.actions[i].invoke()
                    break
                }
            }
        }

        // Mark as read
        markAsRead(id)
    }

    function markAsRead(id) {
        for (var idx = 0; idx < historyModel.count; idx++) {
            if (historyModel.get(idx).id === id) {
                historyModel.setProperty(idx, "unread", false)
                break
            }
        }
        updateUnreadCount()
    }

    function markAllAsRead() {
        for (var idx = 0; idx < historyModel.count; idx++) {
            historyModel.setProperty(idx, "unread", false)
        }
        updateUnreadCount()
    }

    function updateUnreadCount() {
        var count = 0
        for (var idx = 0; idx < historyModel.count; idx++) {
            if (historyModel.get(idx).unread) {
                count++
            }
        }
        unreadCount = count
    }
}
