hl.on("hyprland.start", function()

    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("gsr-ui launch-daemon")

    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    hl.exec_cmd("wal -R -n")

    hl.exec_cmd("~/.config/scripts/start-quickshell.sh")
    hl.exec_cmd("~/.config/waybar/launch.sh")

    hl.exec_cmd("swaync")
    hl.exec_cmd("mpd-mpris")
    hl.exec_cmd("kdeconnect-indicator")

    -- Import environment variables to systemd user session
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP XDG_MENU_PREFIX XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS")

    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP XDG_MENU_PREFIX XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS")

    hl.exec_cmd("kbuildsycoca6 --noincremental")

    hl.exec_cmd("systemctl --user start hyprland-session.target")

    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

end)
