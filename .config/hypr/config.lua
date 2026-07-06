require("monitors")

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-----------------------
---- LOOK & FEEL ------
-----------------------

hl.config({

    general = {
        gaps_in = 6,
        gaps_out = 8,

        border_size = 1,

        col = {
            active_border = "rgb(585b70)",
            inactive_border = "rgb(2a2b36)",
        },

        layout = "dwindle",
    },

    decoration = {

        rounding = 16,

        active_opacity = 1.0,
        inactive_opacity = 0.9,

        dim_inactive = true,
        dim_strength = 0.04,

        shadow = {
            enabled = true,
            range = 35,
            render_power = 4,
            color = "rgba(00000050)",
        },

        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            noise = 0.006,
            brightness = 1.03,
            contrast = 1.02,
            vibrancy = 0.25,
            vibrancy_darkness = 0.6,
            xray = false,
            popups = true,
            special = true,
        },
    },

    input = {
        kb_layout = "latam",

        follow_mouse = 1,
        mouse_refocus = false,

        touchpad = {
            disable_while_typing = true,
            natural_scroll = true,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo = true,
        animate_manual_resizes = true,
        animate_mouse_windowdragging = true,
        vrr = 1,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        layers_hog_keyboard_focus = true,
        focus_on_activate = true,
    },

    cursor = {
        inactive_timeout = 3,
    },

})