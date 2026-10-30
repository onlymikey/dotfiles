pragma Singleton
import QtQuick

QtObject {
    id: i18n

    property string language: "es"
    readonly property bool isSpanish: language === "es"

    function t(key, fallback) {
        var bundle = (language === "en") ? en : es
        if (bundle && bundle[key] !== undefined) return bundle[key]
        if (es && es[key] !== undefined) return es[key]
        return fallback !== undefined ? fallback : key
    }

    readonly property var s: (language === "en") ? en : es

    readonly property var es: ({
        // General / Common
        "close": "Cerrar",
        "confirm": "Confirmar",
        "cancel": "Cancelar",
        "save": "Guardar",
        "apply": "Aplicar",
        "revert": "Revertir",
        "enabled": "Activado",
        "disabled": "Desactivado",
        "search": "Buscar...",

        // Settings Panel Header
        "settings_title": "Configuración del Sistema",
        "settings_subtitle": "Pantallas, idioma de la shell, teclado y preferencias",
        "settings_tab_monitors": "Pantallas",
        "settings_tab_input": "Idioma y Entrada",
        "settings_tab_appearance": "Apariencia",
        "settings_tab_info": "Información",

        // Settings - Displays Tab
        "mon_safety_revert": "¿Conservar cambios? Reversión en %1s",
        "mon_keep_changes": "Conservar",
        "mon_revert_now": "Revertir ahora",
        "mon_proj_modes": "Modos de Proyección",
        "mon_mode_extend": "Extender",
        "mon_mode_extend_sub": "Todas (%1)",
        "mon_mode_mirror": "Duplicar",
        "mon_mode_primary": "Principal",
        "mon_mode_external": "Externa",
        "mon_off": "Pantalla apagada",
        "mon_mirroring_to": "Duplicando a %1",
        "mon_make_primary": "Hacer Principal",
        "mon_is_primary": "★ Principal",
        "mon_res_hz": "Resolución y Frecuencia",
        "mon_priority_global": "Prioridad global:",
        "mon_priority_highrr": "Alta Frecuencia (Hz)",
        "mon_priority_highres": "Calidad / Resolución",
        "mon_scale": "Escala de visualización",
        "mon_position": "Posición",
        "mon_pos_left": "← Izq",
        "mon_pos_right": "Der →",
        "mon_pos_above": "↑ Arriba",
        "mon_pos_below": "↓ Abajo",

        // Settings - Language & Input Tab
        "shell_lang_title": "Idioma de la Shell",
        "shell_lang_desc": "Cambia exclusivamente el idioma de la interfaz de Quickshell (paneles, barras y menús). No altera el idioma de tus programas ni la configuración del sistema.",
        "lang_es": "Español (Latinoamérica)",
        "lang_en": "English (United States)",
        "kbd_title": "Distribución de Teclado",
        "kbd_active": "Mapa activo: %1",
        "kbd_us_intl": "US Internacional",
        "kbd_us_intl_desc": "Alt-Gr para ñ, acentos con teclas muertas",
        "kbd_latam": "Español Latinoamericano",
        "kbd_latam_desc": "ñ al lado de la L, signos directos",
        "kbd_es": "Español (España)",
        "kbd_es_desc": "Distribución estándar ISO España",
        "kbd_us": "US Estándar",
        "kbd_us_desc": "Sin teclas muertas para programación rápida",
        "posix_title": "Configuración Regional del Sistema (POSIX)",
        "posix_desc": "Variable LANG: %1 · Formato de fecha y números conforme al sistema operativo.",

        // Settings - Appearance Tab
        "app_scaling_title": "Escalado y Tipografía de Quickshell",
        "app_scaling_sub": "Línea base: 1080p = 1.0x · Factor actual: %1x (%2)",
        "app_dpi_std": "DPI Estándar",
        "app_dpi_hi": "HiDPI",
        "app_scaling_desc": "Fuente de interfaz: JetBrainsMono Nerd Font · Los pisos mínimos de legibilidad están activados para garantizar texto 100% nítido en pantallas 1080p.",

        // Settings - Info Tab
        "info_edition": "Arch Linux · Mikey's Edition",
        "info_stack": "Compositor: Hyprland (Hyprlua) · Shell: Quickshell",
        "info_host": "Equipo: %1",
        "info_kernel": "Kernel: %1",
        "info_locale": "Locale del sistema: %1",

        // Launcher
        "launcher_tab_apps": "Apps",
        "launcher_tab_walls": "Fondos",
        "launcher_tab_clipboard": "Portapapeles",
        "launcher_search_apps": "Buscar aplicaciones...",
        "launcher_search_walls": "Buscar fondos...",
        "launcher_search_clipboard": "Buscar en portapapeles...",
        "launcher_no_apps": "No se encontraron aplicaciones",
        "launcher_no_walls": "No se encontraron fondos",
        "launcher_no_clipboard": "Portapapeles vacío",

        // Calendar
        "cal_events": "Eventos",
        "cal_no_events": "Sin eventos programados",
        "cal_days": ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"],
        "cal_months": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"],

        // Dashboard
        "dash_title": "Panel de Control",
        "dash_vol": "Volumen",
        "dash_bright": "Brillo",
        "dash_overamp": "Modo Desquiciado (150%)",
        "dash_power_mode": "Perfil de Energía",
        "dash_battery": "Batería",
        "dash_audio_out": "Dispositivos de Salida",
        "dash_audio_in": "Dispositivos de Entrada",
        "pwr_lock": "Bloquear",
        "pwr_suspend": "Suspender",
        "pwr_hibernate": "Hibernar",
        "pwr_reboot": "Reiniciar",
        "pwr_shutdown": "Apagar",

        // Notifications
        "notif_title": "Notificaciones",
        "notif_clear": "Limpiar todo",
        "notif_empty": "No hay notificaciones",
        "notif_see_more": "Ver más ▾",
        "notif_see_less": "Ver menos ▴",

        // Connected Devices (Android Integration)
        "cd_title": "Dispositivos Conectados",
        "cd_no_device": "Sin dispositivos conectados",
        "cd_no_device_sub": "Conecta tu teléfono por USB o en la misma red Wi-Fi para KDE Connect o depuración ADB.",
        "cd_battery": "Batería",
        "cd_network": "Red",
        "cd_signal": "Potencia de Señal",
        "cd_notifications": "Notificaciones",
        "cd_scrcpy_btn": "Transmitir y controlar pantalla (scrcpy)",
        "cd_scrcpy_disabled": "scrcpy requiere depuración USB / ADB activa y autorizada",
        "cd_scrcpy_running": "scrcpy en ejecución (clic para enfocar ventana)",
        "cd_ring_btn": "Hacer sonar el teléfono (Find Phone)",
        "cd_ring_disabled": "Requiere teléfono vinculado y accesible vía KDE Connect",
        "cd_charging": "Cargando",
        "cd_connected_via": "Conectado vía %1",
        "cd_offline": "Desconectado"
    })

    readonly property var en: ({
        // General / Common
        "close": "Close",
        "confirm": "Confirm",
        "cancel": "Cancel",
        "save": "Save",
        "apply": "Apply",
        "revert": "Revert",
        "enabled": "Enabled",
        "disabled": "Disabled",
        "search": "Search...",

        // Settings Panel Header
        "settings_title": "System Settings",
        "settings_subtitle": "Displays, shell language, keyboard and preferences",
        "settings_tab_monitors": "Displays",
        "settings_tab_input": "Language & Input",
        "settings_tab_appearance": "Appearance",
        "settings_tab_info": "About System",

        // Settings - Displays Tab
        "mon_safety_revert": "Keep changes? Reverting in %1s",
        "mon_keep_changes": "Keep",
        "mon_revert_now": "Revert now",
        "mon_proj_modes": "Projection Modes",
        "mon_mode_extend": "Extend",
        "mon_mode_extend_sub": "All (%1)",
        "mon_mode_mirror": "Duplicate",
        "mon_mode_primary": "Primary",
        "mon_mode_external": "External",
        "mon_off": "Display turned off",
        "mon_mirroring_to": "Mirroring to %1",
        "mon_make_primary": "Make Primary",
        "mon_is_primary": "★ Primary",
        "mon_res_hz": "Resolution & Refresh Rate",
        "mon_priority_global": "Global Priority:",
        "mon_priority_highrr": "High Refresh Rate (Hz)",
        "mon_priority_highres": "Quality / Resolution",
        "mon_scale": "Display Scale",
        "mon_position": "Position",
        "mon_pos_left": "← Left",
        "mon_pos_right": "Right →",
        "mon_pos_above": "↑ Above",
        "mon_pos_below": "↓ Below",

        // Settings - Language & Input Tab
        "shell_lang_title": "Shell Language",
        "shell_lang_desc": "Changes exclusively the Quickshell UI language (panels, bars and menus). Does not alter your applications or system locale.",
        "lang_es": "Español (Latinoamérica)",
        "lang_en": "English (United States)",
        "kbd_title": "Keyboard Layout",
        "kbd_active": "Active keymap: %1",
        "kbd_us_intl": "US International",
        "kbd_us_intl_desc": "Alt-Gr for ñ, dead key accents",
        "kbd_latam": "Spanish (Latin America)",
        "kbd_latam_desc": "ñ next to L, direct opening marks",
        "kbd_es": "Spanish (Spain)",
        "kbd_es_desc": "ISO standard Spain distribution",
        "kbd_us": "US Standard",
        "kbd_us_desc": "No dead keys for fast programming",
        "posix_title": "System Regional Settings (POSIX)",
        "posix_desc": "LANG variable: %1 · Date and number formatting governed by OS.",

        // Settings - Appearance Tab
        "app_scaling_title": "Quickshell Scaling & Typography",
        "app_scaling_sub": "Baseline: 1080p = 1.0x · Current factor: %1x (%2)",
        "app_dpi_std": "Standard DPI",
        "app_dpi_hi": "HiDPI",
        "app_scaling_desc": "Interface font: JetBrainsMono Nerd Font · Readability floor limits are active to guarantee 100% crisp text on 1080p screens.",

        // Settings - Info Tab
        "info_edition": "Arch Linux · Mikey's Edition",
        "info_stack": "Compositor: Hyprland (Hyprlua) · Shell: Quickshell",
        "info_host": "Host: %1",
        "info_kernel": "Kernel: %1",
        "info_locale": "System locale: %1",

        // Launcher
        "launcher_tab_apps": "Apps",
        "launcher_tab_walls": "Walls",
        "launcher_tab_clipboard": "Clipboard",
        "launcher_search_apps": "Search apps...",
        "launcher_search_walls": "Search wallpapers...",
        "launcher_search_clipboard": "Search clipboard...",
        "launcher_no_apps": "No apps found",
        "launcher_no_walls": "No wallpapers found",
        "launcher_no_clipboard": "Clipboard is empty",

        // Calendar
        "cal_events": "Events",
        "cal_no_events": "No events scheduled",
        "cal_days": ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"],
        "cal_months": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],

        // Dashboard
        "dash_title": "Control Center",
        "dash_vol": "Volume",
        "dash_bright": "Brightness",
        "dash_overamp": "Overamplification (150%)",
        "dash_power_mode": "Power Profile",
        "dash_battery": "Battery",
        "dash_audio_out": "Output Devices",
        "dash_audio_in": "Input Devices",
        "pwr_lock": "Lock",
        "pwr_suspend": "Suspend",
        "pwr_hibernate": "Hibernate",
        "pwr_reboot": "Reboot",
        "pwr_shutdown": "Shutdown",

        // Notifications
        "notif_title": "Notifications",
        "notif_clear": "Clear all",
        "notif_empty": "No notifications",
        "notif_see_more": "See more ▾",
        "notif_see_less": "See less ▴",

        // Connected Devices (Android Integration)
        "cd_title": "Connected Devices",
        "cd_no_device": "No connected devices",
        "cd_no_device_sub": "Connect your phone via USB or on the same Wi-Fi network for KDE Connect or ADB debugging.",
        "cd_battery": "Battery",
        "cd_network": "Network",
        "cd_signal": "Signal Strength",
        "cd_notifications": "Notifications",
        "cd_scrcpy_btn": "Mirror and control screen (scrcpy)",
        "cd_scrcpy_disabled": "scrcpy requires USB / ADB debugging active and authorized",
        "cd_scrcpy_running": "scrcpy is running (click to focus window)",
        "cd_ring_btn": "Ring phone (Find Phone)",
        "cd_ring_disabled": "Requires phone paired and reachable via KDE Connect",
        "cd_charging": "Charging",
        "cd_connected_via": "Connected via %1",
        "cd_offline": "Offline"
    })
}
