hl.window_rule({
    name = "mpv",
    match = {
        class = "^mpv$"
    },

    float = true,
    center = true,
})

hl.window_rule({
    name = "scratchterm",
    match = {
        class = "^scratchterm$"
    },

    float = true,
    center = true,
    size = "85% 70%",
})

hl.window_rule({
    name = "scrcpy",
    match = {
        title = "^scrcpy.*"
    },

    float = true,
    center = true,
    size = "440 920",
})

local opacity_rules = {
    { "Lorien", 0.8 },
    { "sublime_text", 0.88 },
    { "thunar", 0.9 },
    { "Thunar", 0.9 },
    { "VSCodium", 0.88 },
    { "codium", 0.88 },
    { "org.pwmt.zathura", 0.9 },
    { "firefox", 1.0 },
}

for _, rule in ipairs(opacity_rules) do
    hl.window_rule({
        name = "opacity-" .. rule[1],

        match = {
            class = "^" .. rule[1] .. "$"
        },

        opacity = string.format("%.2f %.2f", rule[2], 1.0),
    })
end

----------------------
---- LAYER RULES -----
----------------------

hl.layer_rule({
    name = "waybar",

    match = {
        namespace = "^waybar$"
    },

    blur = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name = "swaync-control",

    match = {
        namespace = "^swaync-control-center$"
    },

    blur = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name = "swaync-notifications",

    match = {
        namespace = "^swaync-notification-window$"
    },

    blur = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name = "quickshell",

    match = {
        namespace = "^quickshell$"
    },

    blur = true,
    ignore_alpha = 0.5,
})