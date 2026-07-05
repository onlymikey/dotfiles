---------------------
---- KEYBINDINGS ----
---------------------

local mod = "SUPER"

-- Terminal
hl.bind(mod .. " + RETURN",
    hl.dsp.exec_cmd("kitty"))

-- Terminal flotante
hl.bind(mod .. " + SHIFT + RETURN",
    hl.dsp.exec_cmd("[float; size 700 400] kitty"))

-- Launcher
hl.bind(mod .. " + R",
    hl.dsp.exec_cmd("qs ipc call launcher toggle"))
    
-- Cerrar ventana
hl.bind(mod .. " + Q",
    hl.dsp.window.close())

-- Toggle floating
hl.bind(mod .. " + F",
    hl.dsp.window.float({ action = "toggle" }))

-- Wallpaper menu
hl.bind(mod .. " + W",
    hl.dsp.exec_cmd("qs ipc call wallpaper toggle"))

-- Wallpaper aleatorio
hl.bind(mod .. " + SHIFT + W",
    hl.dsp.exec_cmd("~/.config/scripts/random-wallpaper.sh"))

-- Lock
hl.bind(mod .. " + ESCAPE",
    hl.dsp.exec_cmd("hyprlock"))

-- Dashboard
hl.bind(mod .. " + A",
    hl.dsp.exec_cmd("qs ipc call dashboard toggle"))

-- Music
hl.bind(mod .. " + M",
    hl.dsp.exec_cmd("qs ipc call music toggle"))

-- Notifications
hl.bind(mod .. " + N",
    hl.dsp.exec_cmd("qs ipc call notifications toggle"))

---------------------
---- FOCUSING -------
---------------------

hl.bind(mod .. " + LEFT",
    hl.dsp.focus({ direction = "left" }))

hl.bind(mod .. " + RIGHT",
    hl.dsp.focus({ direction = "right" }))

hl.bind(mod .. " + UP",
    hl.dsp.focus({ direction = "up" }))

hl.bind(mod .. " + DOWN",
    hl.dsp.focus({ direction = "down" }))

---------------------
---- MOVE WINDOW ----
---------------------

hl.bind(mod .. " + SHIFT + LEFT",
    hl.dsp.window.move({ direction = "left" }))

hl.bind(mod .. " + SHIFT + RIGHT",
    hl.dsp.window.move({ direction = "right" }))

hl.bind(mod .. " + SHIFT + UP",
    hl.dsp.window.move({ direction = "up" }))

hl.bind(mod .. " + SHIFT + DOWN",
    hl.dsp.window.move({ direction = "down" }))

for i = 1, 5 do
    hl.bind(
        mod .. " + " .. i,
        hl.dsp.focus({ workspace = i })
    )

    hl.bind(
        mod .. " + SHIFT + " .. i,
        hl.dsp.window.move({ workspace = i })
    )
end

hl.bind(
    mod .. " + S",
    hl.dsp.workspace.toggle_special("magic")
)

hl.bind(
    mod .. " + SHIFT + S",
    hl.dsp.window.move({
        workspace = "special:magic"
    })
)

hl.bind(
    mod .. " + mouse_down",
    hl.dsp.focus({
        workspace = "e+1"
    })
)

hl.bind(
    mod .. " + mouse_up",
    hl.dsp.focus({
        workspace = "e-1"
    })
)

hl.bind(
    mod .. " + mouse:272",
    hl.dsp.window.drag(),
    { mouse = true }
)

hl.bind(
    mod .. " + mouse:273",
    hl.dsp.window.resize(),
    { mouse = true }
)


hl.bind(
    "F1",
    hl.dsp.exec_cmd("amixer set Master toggle"),
    { locked = true, repeating = true }
)

hl.bind(
    "F2",
    hl.dsp.exec_cmd("amixer set Master 1%-"),
    { locked = true, repeating = true }
)

hl.bind(
    "F3",
    hl.dsp.exec_cmd("amixer set Master 1%+"),
    { locked = true, repeating = true }
)

hl.bind(
    "XF86AudioMute",
    hl.dsp.exec_cmd("amixer set Master toggle"),
    { locked = true, repeating = true }
)

hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("amixer set Master 1%-"),
    { locked = true, repeating = true }
)

hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("amixer set Master 1%+"),
    { locked = true, repeating = true }
)

hl.bind(
    "PRINT",
    hl.dsp.exec_cmd("~/.config/scripts/screenshot.sh skip")
)

hl.bind(
    mod .. " + SHIFT + V",
    hl.dsp.exec_cmd("bash -lc 'cliphist list | head -n1 | cliphist decode | wl-copy'")
)

hl.bind(
    mod .. " + V",
    hl.dsp.exec_cmd("qs ipc call clipboard toggle")
)

hl.bind(
    "XF86MonBrightnessDown",
    hl.dsp.exec_cmd("brightnessctl set 5%-"),
    { locked = true, repeating = true }
)

hl.bind(
    "XF86MonBrightnessUp",
    hl.dsp.exec_cmd("brightnessctl set +5%"),
    { locked = true, repeating = true }
)

hl.bind(
    mod .. " + SHIFT + X",
    hl.dsp.exec_cmd("hyprctl kill")
)