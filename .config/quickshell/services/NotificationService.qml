import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: service

    property bool dnd: false
    property int unreadCount: 0
    
    // Read-only alias to the grouped history list model
    property alias history: groupedHistoryModel

    // Signal emitted when a new notification should trigger a visual popup on screen
    signal notificationTriggered(int id, string appName, string summary, string body, string appIcon, string image, bool hasDefaultAction, var notifActions)

    // Store raw active C++ Notification objects to invoke actions or dismiss them
    property var activeNotifications: ({})

    ListModel {
        id: historyModel
    }

    ListModel {
        id: groupedHistoryModel
    }

    function addNotificationToGroup(notifData) {
        var app = notifData.appName
        var foundGroupIdx = -1
        for (var i = 0; i < groupedHistoryModel.count; i++) {
            if (groupedHistoryModel.get(i).appName === app) {
                foundGroupIdx = i
                break
            }
        }

        if (foundGroupIdx !== -1) {
            var groupObj = groupedHistoryModel.get(foundGroupIdx)
            var notifs = groupObj.notifications || []
            
            // Check if notification ID already exists in the group (overwrite/update it)
            var existingIdx = -1
            for (var j = 0; j < notifs.length; j++) {
                if (notifs[j].id === notifData.id) {
                    existingIdx = j
                    break
                }
            }
            if (existingIdx !== -1) {
                notifs[existingIdx] = notifData
            } else {
                notifs.unshift(notifData) // Insert new notification at the top of the group
            }
            
            groupedHistoryModel.setProperty(foundGroupIdx, "notifications", notifs)
            groupedHistoryModel.setProperty(foundGroupIdx, "count", notifs.length)
            groupedHistoryModel.setProperty(foundGroupIdx, "latestTimeRaw", notifData.timeRaw)
            
            // Move group to top of the history list (most recently active)
            if (foundGroupIdx > 0) {
                groupedHistoryModel.move(foundGroupIdx, 0, 1)
            }
        } else {
            // Create a new application group at the top
            groupedHistoryModel.insert(0, {
                appName: app,
                appIcon: notifData.appIcon,
                count: 1,
                latestTimeRaw: notifData.timeRaw,
                expanded: false,
                notifications: [ notifData ]
            })
        }
    }

    function removeNotificationFromGroup(id) {
        for (var i = 0; i < groupedHistoryModel.count; i++) {
            var groupObj = groupedHistoryModel.get(i)
            var notifs = groupObj.notifications || []
            var foundIdx = -1
            for (var j = 0; j < notifs.length; j++) {
                if (notifs[j].id === id) {
                    foundIdx = j
                    break
                }
            }
            if (foundIdx !== -1) {
                notifs.splice(foundIdx, 1)
                if (notifs.length === 0) {
                    groupedHistoryModel.remove(i)
                } else {
                    groupedHistoryModel.setProperty(i, "notifications", notifs)
                    groupedHistoryModel.setProperty(i, "count", notifs.length)
                    groupedHistoryModel.setProperty(i, "latestTimeRaw", notifs[0].timeRaw)
                }
                break
            }
        }
    }

    function clearGroup(appName) {
        var foundGroupIdx = -1
        for (var i = 0; i < groupedHistoryModel.count; i++) {
            if (groupedHistoryModel.get(i).appName === appName) {
                foundGroupIdx = i
                break
            }
        }
        if (foundGroupIdx !== -1) {
            var groupObj = groupedHistoryModel.get(foundGroupIdx)
            var notifs = groupObj.notifications || []
            for (var j = 0; j < notifs.length; j++) {
                var notifId = notifs[j].id
                var activeNotif = activeNotifications[notifId]
                if (activeNotif) {
                    activeNotif.dismiss()
                    delete activeNotifications[notifId]
                }
                
                // Also remove from the flat historyModel database
                for (var idx = 0; idx < historyModel.count; idx++) {
                    if (historyModel.get(idx).id === notifId) {
                        historyModel.remove(idx)
                        break
                    }
                }
            }
            groupedHistoryModel.remove(foundGroupIdx)
            updateUnreadCount()
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        
        bodyMarkupSupported: true
        actionsSupported: true

        onNotification: function(notification) {
            notification.tracked = true
            activeNotifications[notification.id] = notification
            
            notification.closed.connect(function(reason) {
                delete activeNotifications[notification.id]
                
                var foundIdx = -1
                for (var idx = 0; idx < historyModel.count; idx++) {
                    if (historyModel.get(idx).id === notification.id) {
                        foundIdx = idx
                        break
                    }
                }
                if (foundIdx !== -1) {
                    historyModel.setProperty(foundIdx, "notifActions", [])
                    // Update actions inside grouped model too
                    updateNotificationActionsInGroup(notification.id, [])
                }
            })

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
                timeRaw: new Date().getTime(),
                timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
                unread: true,
                hasDefaultAction: hasDefault,
                notifActions: actionsList
            }

            if (foundIdx !== -1) {
                historyModel.set(foundIdx, notifData)
            } else {
                historyModel.insert(0, notifData)
            }

            addNotificationToGroup(notifData)
            updateUnreadCount()

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

    function updateNotificationActionsInGroup(id, actionsList) {
        for (var i = 0; i < groupedHistoryModel.count; i++) {
            var groupObj = groupedHistoryModel.get(i)
            var notifs = groupObj.notifications || []
            var found = false
            for (var j = 0; j < notifs.length; j++) {
                if (notifs[j].id === id) {
                    notifs[j].notifActions = actionsList
                    found = true
                    break
                }
            }
            if (found) {
                groupedHistoryModel.setProperty(i, "notifications", notifs)
                break
            }
        }
    }

    function toggleDnd() {
        dnd = !dnd
    }

    function clearNotification(id) {
        var activeNotif = activeNotifications[id]
        if (activeNotif) {
            activeNotif.dismiss()
        }

        for (var idx = 0; idx < historyModel.count; idx++) {
            if (historyModel.get(idx).id === id) {
                historyModel.remove(idx)
                break
            }
        }
        removeNotificationFromGroup(id)
        updateUnreadCount()
    }

    function clearAll() {
        for (var key in activeNotifications) {
            if (activeNotifications.hasOwnProperty(key)) {
                activeNotifications[key].dismiss()
            }
        }
        activeNotifications = {}

        historyModel.clear()
        groupedHistoryModel.clear()
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
        markAsRead(id)
    }

    function markAsRead(id) {
        for (var idx = 0; idx < historyModel.count; idx++) {
            if (historyModel.get(idx).id === id) {
                historyModel.setProperty(idx, "unread", false)
                break
            }
        }
        
        // Mark as read in grouped model too
        for (var i = 0; i < groupedHistoryModel.count; i++) {
            var groupObj = groupedHistoryModel.get(i)
            var notifs = groupObj.notifications || []
            var found = false
            for (var j = 0; j < notifs.length; j++) {
                if (notifs[j].id === id) {
                    notifs[j].unread = false
                    found = true
                    break
                }
            }
            if (found) {
                groupedHistoryModel.setProperty(i, "notifications", notifs)
                break
            }
        }
        
        updateUnreadCount()
    }

    function markAllAsRead() {
        for (var idx = 0; idx < historyModel.count; idx++) {
            historyModel.setProperty(idx, "unread", false)
        }
        
        // Mark all as read in grouped model too
        for (var i = 0; i < groupedHistoryModel.count; i++) {
            var groupObj = groupedHistoryModel.get(i)
            var notifs = groupObj.notifications || []
            for (var j = 0; j < notifs.length; j++) {
                notifs[j].unread = false
            }
            groupedHistoryModel.setProperty(i, "notifications", notifs)
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

    onDndChanged: {
        if (root && root.saveState) {
            root.saveState("dnd", dnd ? "true" : "false")
        }
    }
}
