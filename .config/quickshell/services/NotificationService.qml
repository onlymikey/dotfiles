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

    function normalizeGroupKey(appName) {
        var cleaned = (appName || "Notification").trim()
        if (cleaned === "") cleaned = "Notification"
        return cleaned.toLowerCase()
    }

    function addNotificationToGroup(notifData) {
        var app = (notifData.appName || "Notification").trim()
        if (app === "") app = "Notification"
        var groupKey = normalizeGroupKey(app)

        var foundGroupIdx = -1
        for (var i = 0; i < groupedHistoryModel.count; i++) {
            if (groupedHistoryModel.get(i).groupKey === groupKey) {
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

            var latest = notifsModel.get(0)
            groupedHistoryModel.setProperty(foundGroupIdx, "count", notifsModel.count)
            groupedHistoryModel.setProperty(foundGroupIdx, "latestTimeRaw", latest.timeRaw)
            groupedHistoryModel.setProperty(foundGroupIdx, "latestSummary", latest.summary || "")
            groupedHistoryModel.setProperty(foundGroupIdx, "latestBody", latest.body || "")
            if (notifData.appIcon && notifData.appIcon !== "") {
                groupedHistoryModel.setProperty(foundGroupIdx, "appIcon", notifData.appIcon)
            }

            // Move group to top of the history list (most recently active)
            if (foundGroupIdx > 0) {
                groupedHistoryModel.move(foundGroupIdx, 0, 1)
            }
        } else {
            // Create a new application group at the top (expanded by default so notifications are visible)
            groupedHistoryModel.insert(0, {
                groupKey: groupKey,
                appName: app,
                appIcon: notifData.appIcon || "",
                count: 1,
                latestTimeRaw: notifData.timeRaw,
                latestSummary: notifData.summary || "",
                latestBody: notifData.body || "",
                expanded: true,
                notifications: [ notifData ]
            })
        }
    }

    function removeNotificationFromGroup(id) {
        for (var i = 0; i < groupedHistoryModel.count; i++) {
            var groupObj = groupedHistoryModel.get(i)
            var notifsModel = groupObj.notifications
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
                    var latest = notifsModel.get(0)
                    groupedHistoryModel.setProperty(i, "count", notifsModel.count)
                    groupedHistoryModel.setProperty(i, "latestTimeRaw", latest.timeRaw)
                    groupedHistoryModel.setProperty(i, "latestSummary", latest.summary || "")
                    groupedHistoryModel.setProperty(i, "latestBody", latest.body || "")
                }
                break
            }
        }
    }

    function clearGroup(appName) {
        var targetKey = normalizeGroupKey(appName)
        var foundGroupIdx = -1
        for (var i = 0; i < groupedHistoryModel.count; i++) {
            var g = groupedHistoryModel.get(i)
            if (g.groupKey === targetKey || g.appName === appName) {
                foundGroupIdx = i
                break
            }
        }
        if (foundGroupIdx !== -1) {
            var groupObj = groupedHistoryModel.get(foundGroupIdx)
            var notifsModel = groupObj.notifications
            while (notifsModel.count > 0) {
                var notifId = notifsModel.get(0).notifId
                var activeNotif = activeNotifications[notifId]
                if (activeNotif) {
                    delete activeNotifications[notifId]
                    activeNotif.dismiss()
                }

                for (var idx = 0; idx < historyModel.count; idx++) {
                    if (historyModel.get(idx).id === notifId) {
                        historyModel.remove(idx)
                        break
                    }
                }
                if (notifsModel.count > 0 && notifsModel.get(0).notifId === notifId) {
                    notifsModel.remove(0)
                }
            }
            if (foundGroupIdx < groupedHistoryModel.count && groupedHistoryModel.get(foundGroupIdx).groupKey === targetKey) {
                groupedHistoryModel.remove(foundGroupIdx)
            }
            updateUnreadCount()
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true

        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        inlineReplySupported: true

        onNotification: function(notification) {
            notification.tracked = true
            var nId = notification.id
            activeNotifications[nId] = notification

            notification.closed.connect(function(reason) {
                delete activeNotifications[nId]

                // Reason 2 is dismissed by user -> remove from history.
                // Otherwise keep in history and disable live D-Bus actions since the sender closed the handle.
                if (reason === 2) {
                    clearNotification(nId)
                } else {
                    for (var idx = 0; idx < historyModel.count; idx++) {
                        if (historyModel.get(idx).id === nId) {
                            historyModel.setProperty(idx, "notifActionsJson", "[]")
                            historyModel.setProperty(idx, "hasInlineReply", false)
                            break
                        }
                    }
                    updateNotificationActionsInGroup(nId, "[]", false)
                }
            })

            var actionsList = []
            var hasDefault = false
            var hasInline = Boolean(
                notification.hasInlineReply ||
                (notification.hints && (
                    notification.hints["x-kde-receive-reply"] === true ||
                    String(notification.hints["x-kde-receive-reply"]) === "true" ||
                    notification.hints["x-kde-reply-placeholder-text"] !== undefined
                ))
            )

            if (notification.actions) {
                for (var i = 0; i < notification.actions.length; i++) {
                    var actionId = notification.actions[i].identifier
                    var actionText = notification.actions[i].text || ""

                    if (actionId === "default") {
                        hasDefault = true
                    } else if (actionId === "inline-reply") {
                        hasInline = true
                    } else {
                        var displayLabel = actionText
                        if (displayLabel.indexOf(":") !== -1) {
                            displayLabel = displayLabel.substring(displayLabel.indexOf(":") + 1)
                        }
                        if (displayLabel.trim() !== "") {
                            actionsList.push({
                                identifier: actionId,
                                text: displayLabel.trim()
                            })
                        }
                    }
                }
            }

            var foundIdx = -1
            for (var idx = 0; idx < historyModel.count; idx++) {
                if (historyModel.get(idx).id === nId) {
                    foundIdx = idx
                    break
                }
            }

            var nowMs = new Date().getTime()
            var actionsJsonStr = JSON.stringify(actionsList)
            var notifData = {
                notifId: nId,
                id: nId,
                appName: (notification.appName || "Notification").trim() || "Notification",
                summary: notification.summary || "",
                body: notification.body || "",
                appIcon: notification.appIcon || "",
                image: notification.image || "",
                urgency: notification.urgency,
                timeRaw: nowMs,
                timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
                unread: true,
                hasDefaultAction: hasDefault,
                notifActionsJson: actionsJsonStr,
                hasInlineReply: hasInline
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
                    nId,
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

    function updateNotificationActionsInGroup(id, actionsJsonStr, hasInlineVal) {
        for (var i = 0; i < groupedHistoryModel.count; i++) {
            var groupObj = groupedHistoryModel.get(i)
            var notifsModel = groupObj.notifications
            var found = false
            for (var j = 0; j < notifsModel.count; j++) {
                if (notifsModel.get(j).notifId === id) {
                    notifsModel.setProperty(j, "notifActionsJson", actionsJsonStr)
                    if (typeof hasInlineVal !== "undefined") {
                        notifsModel.setProperty(j, "hasInlineReply", Boolean(hasInlineVal))
                    }
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
            delete activeNotifications[id]
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
        var activeCopy = activeNotifications
        activeNotifications = ({})
        for (var key in activeCopy) {
            if (activeCopy.hasOwnProperty(key) && activeCopy[key]) {
                activeCopy[key].dismiss()
            }
        }

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

        for (var i = 0; i < groupedHistoryModel.count; i++) {
            var groupObj = groupedHistoryModel.get(i)
            var notifsModel = groupObj.notifications
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

        for (var i = 0; i < groupedHistoryModel.count; i++) {
            var groupObj = groupedHistoryModel.get(i)
            var notifsModel = groupObj.notifications
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
