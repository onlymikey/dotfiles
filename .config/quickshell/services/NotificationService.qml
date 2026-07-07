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
    signal notificationTriggered(int id, string appName, string summary, string body, string appIcon, string image, bool hasDefaultAction, var notifActions, bool hasInlineReply)

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
            var notifsModel = groupObj.notifications // Nested ListModel
            
            // Check if notification ID already exists in the group (overwrite/update it)
            var existingIdx = -1
            for (var j = 0; j < notifsModel.count; j++) {
                if (notifsModel.get(j).notifId === notifData.notifId) {
                    existingIdx = j
                    break
                }
            }
            if (existingIdx !== -1) {
                notifsModel.set(existingIdx, notifData)
            } else {
                notifsModel.insert(0, notifData) // Insert new notification at the top of the group
            }
            
            groupedHistoryModel.setProperty(foundGroupIdx, "count", notifsModel.count)
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
                notifications: [ notifData ] // QML automatically converts this array to a ListModel
            })
        }
    }

    function removeNotificationFromGroup(id) {
        for (var i = 0; i < groupedHistoryModel.count; i++) {
            var groupObj = groupedHistoryModel.get(i)
            var notifsModel = groupObj.notifications // Nested ListModel
            var foundIdx = -1
            for (var j = 0; j < notifsModel.count; j++) {
                if (notifsModel.get(j).notifId === id) {
                    foundIdx = j
                    break
                }
            }
            if (foundIdx !== -1) {
                notifsModel.remove(foundIdx)
                if (notifsModel.count === 0) {
                    groupedHistoryModel.remove(i)
                } else {
                    groupedHistoryModel.setProperty(i, "count", notifsModel.count)
                    groupedHistoryModel.setProperty(i, "latestTimeRaw", notifsModel.get(0).timeRaw)
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
            var notifsModel = groupObj.notifications // Nested ListModel
            while (notifsModel.count > 0) {
                var notifId = notifsModel.get(0).notifId
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
                notifsModel.remove(0)
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
        inlineReplySupported: true

        onNotification: function(notification) {
            notification.tracked = true
            activeNotifications[notification.id] = notification
            
            notification.closed.connect(function(reason) {
                delete activeNotifications[notification.id]
                
                // Reason 1 is expired/timeout (keep in history, but clear buttons so they can't be clicked)
                if (reason === 1) {
                    var foundIdx = -1
                    for (var idx = 0; idx < historyModel.count; idx++) {
                        if (historyModel.get(idx).id === notification.id) {
                            foundIdx = idx
                            break
                        }
                    }
                    if (foundIdx !== -1) {
                        historyModel.setProperty(foundIdx, "notifActions", [])
                        updateNotificationActionsInGroup(notification.id, [])
                    }
                } else {
                    // Reason 2 (dismissed by user), 3 (closed by app), etc. (remove from history entirely)
                    clearNotification(notification.id)
                }
            })

            var actionsList = []
            var hasDefault = false
            if (notification.actions) {
                for (var i = 0; i < notification.actions.length; i++) {
                    var actionId = notification.actions[i].identifier
                    var actionText = notification.actions[i].text || ""
                    
                    if (actionId === "default") {
                        hasDefault = true
                    } else {
                        var displayLabel = actionText
                        if (displayLabel.indexOf(":") !== -1) {
                            displayLabel = displayLabel.substring(displayLabel.indexOf(":") + 1)
                        }
                        actionsList.push({
                            identifier: actionId,
                            text: displayLabel
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
                notifId: notification.id,
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
                notifActions: actionsList,
                hasInlineReply: notification.hasInlineReply || (notification.hints && (notification.hints["x-kde-receive-reply"] === true || String(notification.hints["x-kde-receive-reply"]) === "true"))
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
                    actionsList,
                    notifData.hasInlineReply
                )
            }
        }
    }

    function updateNotificationActionsInGroup(id, actionsList) {
        for (var i = 0; i < groupedHistoryModel.count; i++) {
            var groupObj = groupedHistoryModel.get(i)
            var notifsModel = groupObj.notifications // Nested ListModel
            var found = false
            for (var j = 0; j < notifsModel.count; j++) {
                if (notifsModel.get(j).notifId === id) {
                    notifsModel.setProperty(j, "notifActions", actionsList)
                    found = true
                    break
                }
            }
            if (found) {
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

    function sendReply(id, replyText) {
        var activeNotif = activeNotifications[id]
        if (activeNotif) {
            if (typeof activeNotif.sendInlineReply === "function") {
                activeNotif.sendInlineReply(replyText)
            } else {
                console.log("sendInlineReply method not found on notification", id)
            }
        }
        markAsRead(id)
        clearNotification(id)
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
            var notifsModel = groupObj.notifications // Nested ListModel
            var found = false
            for (var j = 0; j < notifsModel.count; j++) {
                if (notifsModel.get(j).notifId === id) {
                    notifsModel.setProperty(j, "unread", false)
                    found = true
                    break
                }
            }
            if (found) {
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
            var notifsModel = groupObj.notifications // Nested ListModel
            for (var j = 0; j < notifsModel.count; j++) {
                notifsModel.setProperty(j, "unread", false)
            }
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
