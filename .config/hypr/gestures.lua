--------------------------------------------------
-- Touchpad Gestures
--------------------------------------------------

-- Workspace swipe (nativo de Hyprland)
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

--------------------------------------------------
-- Three Fingers
--------------------------------------------------

-- Open (Dashboard)
hl.gesture({
    fingers = 3,
    direction = "up",
    action = function()
        hl.exec_cmd("bash -lc 'qs ipc call gestures trigger swipe-up'")
    end
})

-- Close current panel
hl.gesture({
    fingers = 3,
    direction = "down",
    action = function()
        hl.exec_cmd("bash -lc 'qs ipc call gestures trigger swipe-down'")
    end
})

--------------------------------------------------
-- Four Fingers
--------------------------------------------------

-- Clipboard
hl.gesture({
    fingers = 4,
    direction = "up",
    action = function()
        hl.exec_cmd("bash -lc 'qs ipc call gestures trigger four-up'")
    end
})

-- Music
hl.gesture({
    fingers = 4,
    direction = "down",
    action = function()
        hl.exec_cmd("bash -lc 'qs ipc call gestures trigger four-down'")
    end
})

-- Notifications
hl.gesture({
    fingers = 4,
    direction = "left",
    action = function()
        hl.exec_cmd("bash -lc 'qs ipc call gestures trigger four-left'")
    end
})

-- Launcher
hl.gesture({
    fingers = 4,
    direction = "right",
    action = function()
        hl.exec_cmd("bash -lc 'qs ipc call gestures trigger four-right'")
    end
})