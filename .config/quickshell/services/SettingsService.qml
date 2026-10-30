import Quickshell
import Quickshell.Io
import QtCore
import QtQuick
import "../theme"

Item {
    id: service

    property string language: "es" // "es" or "en"
    property string systemLocale: "es_MX.UTF-8"
    property string keyboardLayout: "us"
    property string keyboardVariant: "intl"
    property string activeKeymap: "English (US, intl., with dead keys)"
    property string systemUptime: ""
    property string kernelVersion: ""
    property string hostName: ""

    onLanguageChanged: {
        I18n.language = language
    }

    readonly property string configDir: String(StandardPaths.writableLocation(StandardPaths.ConfigLocation)).replace("file://", "") + "/quickshell"
    readonly property string langFile: configDir + "/state/language"

    function setLanguage(lang) {
        service.language = lang
        I18n.language = lang
        saveLangProc.command = ["bash", "-c", "mkdir -p '" + configDir + "/state' && echo '" + lang + "' > '" + langFile + "'"]
        saveLangProc.running = true
    }

    function setKeyboardLayout(layout, variant) {
        service.keyboardLayout = layout
        service.keyboardVariant = variant
        setKbdProc.command = [
            "python3", "-c",
            "import re, subprocess, os\n" +
            "p = os.path.expanduser('~/.config/hypr/config.lua')\n" +
            "txt = open(p).read()\n" +
            "txt = re.sub(r'kb_layout\\s*=\\s*\"[^\"]*\"', f'kb_layout = \"{layout}\"', txt)\n" +
            "txt = re.sub(r'kb_variant\\s*=\\s*\"[^\"]*\"', f'kb_variant = \"{variant}\"', txt)\n" +
            "open(p, 'w').write(txt)\n" +
            "subprocess.run(['hyprctl', 'reload'])\n"
        ]
        setKbdProc.running = true
    }

    function refresh() {
        queryInfoProc.running = true
    }

    Process {
        id: saveLangProc
    }

    Process {
        id: setKbdProc
        onExited: {
            service.refresh()
        }
    }

    Process {
        id: queryInfoProc
        command: [
            "python3", "-c",
            "import os, json, subprocess\n" +
            "lang = 'es'\n" +
            "lp = os.path.expanduser('~/.config/quickshell/state/language')\n" +
            "if os.path.exists(lp):\n" +
            "    try: lang = open(lp).read().strip() or 'es'\n" +
            "    except: pass\n" +
            "loc = os.environ.get('LANG', 'es_MX.UTF-8')\n" +
            "kbd_layout = 'us'\n" +
            "kbd_variant = 'intl'\n" +
            "active_map = 'English (US, intl., with dead keys)'\n" +
            "try:\n" +
            "    cp = os.path.expanduser('~/.config/hypr/config.lua')\n" +
            "    txt = open(cp).read()\n" +
            "    import re\n" +
            "    lm = re.search(r'kb_layout\\s*=\\s*\"([^\"]+)\"', txt)\n" +
            "    vm = re.search(r'kb_variant\\s*=\\s*\"([^\"]+)\"', txt)\n" +
            "    if lm: kbd_layout = lm.group(1)\n" +
            "    if vm: kbd_variant = vm.group(1)\n" +
            "except: pass\n" +
            "try:\n" +
            "    devs = json.loads(subprocess.check_output(['hyprctl', 'devices', '-j']).decode())\n" +
            "    for k in devs.get('keyboards', []):\n" +
            "        if k.get('active_keymap'):\n" +
            "            active_map = k['active_keymap']\n" +
            "            break\n" +
            "except: pass\n" +
            "kernel = ''\n" +
            "hostname = ''\n" +
            "try: kernel = subprocess.check_output(['uname', '-r']).decode().strip()\n" +
            "except: pass\n" +
            "try: hostname = subprocess.check_output(['uname', '-n']).decode().strip()\n" +
            "except: pass\n" +
            "print(json.dumps({\n" +
            "    'language': lang,\n" +
            "    'systemLocale': loc,\n" +
            "    'keyboardLayout': kbd_layout,\n" +
            "    'keyboardVariant': kbd_variant,\n" +
            "    'activeKeymap': active_map,\n" +
            "    'kernelVersion': kernel,\n" +
            "    'hostName': hostname\n" +
            "}))\n"
        ]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data.trim())
                    service.language = parsed.language || "es"
                    service.systemLocale = parsed.systemLocale || "es_MX.UTF-8"
                    service.keyboardLayout = parsed.keyboardLayout || "us"
                    service.keyboardVariant = parsed.keyboardVariant || "intl"
                    service.activeKeymap = parsed.activeKeymap || "English (US, intl., with dead keys)"
                    service.kernelVersion = parsed.kernelVersion || ""
                    service.hostName = parsed.hostName || ""
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        refresh()
    }
}
