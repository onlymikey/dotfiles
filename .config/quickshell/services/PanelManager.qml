import QtQuick

QtObject {
    id: manager

    // Shell root host that owns visibility flags and panel actions.
    required property QtObject shell

    property string activePanel: ""
    property string previousPanel: ""

    readonly property var panelNames: ["dashboard", "launcher", "music", "wifi", "bluetooth", "notifications", "calendar"]

    function isKnown(name) {
        return panelNames.indexOf(name) !== -1
    }

    function isOpen(name) {
        if (name === "dashboard") return shell.dashboardVisible
        if (name === "launcher") return shell.launcherVisible
        if (name === "music") return shell.musicVisible
        if (name === "wifi") return shell.wifiVisible
        if (name === "bluetooth") return shell.btVisible
        if (name === "notifications") return shell.notificationsVisible
        if (name === "calendar") return shell.calendarVisible
        return false
    }

    function _setOpen(name, value) {
        if (name === "dashboard") shell.dashboardVisible = value
        else if (name === "launcher") shell.launcherVisible = value
        else if (name === "music") shell.musicVisible = value
        else if (name === "wifi") shell.wifiVisible = value
        else if (name === "bluetooth") shell.btVisible = value
        else if (name === "notifications") shell.notificationsVisible = value
        else if (name === "calendar") shell.calendarVisible = value
    }

    function _applyOpenSideEffects(name, options) {
        var opts = options || ({})

        if (name === "wifi") {
            shell.refreshWifi()
            return
        }

        if (name === "bluetooth") {
            shell.refreshBluetooth()
            return
        }

        if (name === "launcher") {
            if (opts.hasOwnProperty("tab")) {
                shell.activeTab = opts.tab
            }

            if (shell.activeTab === 1 && !shell.wallsLoaded) {
                shell.loadWallpapers()
            }

            if (shell.activeTab === 2) {
                shell.reloadClipboard()
            }
        }
    }

    function open(name, options) {
        if (!isKnown(name)) return

        var opts = options || ({})

        if (activePanel === name) {
            if (name === "launcher" && opts.hasOwnProperty("tab") && shell.activeTab !== opts.tab) {
                _applyOpenSideEffects(name, opts)
            }
            return
        }

        if (activePanel !== "") {
            _setOpen(activePanel, false)
            previousPanel = activePanel
        }

        _setOpen(name, true)
        activePanel = name
        _applyOpenSideEffects(name, opts)
    }

    function close(name) {
        if (name === undefined || name === null || name === "") {
            if (activePanel === "") return
            previousPanel = activePanel
            _setOpen(activePanel, false)
            activePanel = ""
            return
        }

        if (!isKnown(name) || !isOpen(name)) return

        _setOpen(name, false)
        if (activePanel === name) {
            previousPanel = activePanel
            activePanel = ""
        }
    }

    function closeAll() {
        if (activePanel !== "") {
            previousPanel = activePanel
        }

        for (var i = 0; i < panelNames.length; i++) {
            _setOpen(panelNames[i], false)
        }

        activePanel = ""
    }

    function toggle(name, options) {
        if (!isKnown(name)) return

        var opts = options || ({})

        if (activePanel === name) {
            if (name === "launcher" && opts.hasOwnProperty("tab") && shell.activeTab !== opts.tab) {
                _applyOpenSideEffects(name, opts)
                return
            }
            close(name)
            return
        }

        open(name, opts)
    }

    function handleGesture(gesture) {
        if (gesture === "swipe-up" || gesture === "swipe_up") {
            if (activePanel === "") {
                open("dashboard")
            } else if (activePanel === "launcher") {
                close("launcher")
            }
        } else if (gesture === "swipe-down" || gesture === "swipe_down") {
            if (activePanel === "") {
                open("launcher", { tab: 0 })
            } else if (activePanel === "dashboard") {
                close("dashboard")
            }
        } else if (gesture === "four-up" || gesture === "four_up") {
            if (activePanel === "") {
                open("launcher", { tab: 2 })
            } else if (activePanel === "music") {
                close("music")
            }
        } else if (gesture === "four-down" || gesture === "four_down") {
            if (activePanel === "") {
                open("music")
            } else if (activePanel === "launcher") {
                close("launcher")
            }
        } else if (gesture === "four-left" || gesture === "four_left" || gesture === "notifications") {
            if (activePanel === "") {
                open("notifications")
            } else if (activePanel === "launcher") {
                close("launcher")
            }
        } else if (gesture === "four-right" || gesture === "four_right") {
            if (activePanel === "") {
                open("launcher", { tab: 0 })
            } else if (activePanel === "notifications") {
                close("notifications")
            }
        } else {
            console.log("Unhandled or ignored gesture:", gesture)
        }
    }
}
