#!/usr/bin/env python3
import os
import re
import glob
import shlex
import shutil

HOME = os.path.expanduser("~")

DESKTOP_DIRS = [
    os.path.join(HOME, ".local/share/applications"),
    os.path.join(HOME, ".local/share/flatpak/exports/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    "/usr/local/share/applications",
    "/usr/share/applications",
]

APPIMAGE_DIRS = [
    os.path.join(HOME, "Applications"),
    os.path.join(HOME, "AppImages"),
    os.path.join(HOME, ".local/bin"),
]

ICON_SEARCH_DIRS = [
    os.path.join(HOME, ".local/share/icons"),
    os.path.join(HOME, ".icons"),
    os.path.join(HOME, ".local/share/flatpak/exports/share/icons"),
    "/var/lib/flatpak/exports/share/icons",
    "/usr/share/pixmaps",
]

FIELD_CODE_RE = re.compile(r"\s+%[fFuUdDnNickvm]\b")


def resolve_icon(icon_val):
    if not icon_val:
        return ""
    icon_val = icon_val.strip()
    if icon_val.startswith("/"):
        return icon_val if os.path.exists(icon_val) else ""

    # Check Flatpak & local icon directories first if it's a custom/Flatpak icon
    preferred_sizes = ["128x128", "64x64", "256x256", "48x48", "scalable", "512x512", "32x32"]
    exts = [".svg", ".png", ".xpm"]

    for base in ICON_SEARCH_DIRS:
        if not os.path.isdir(base):
            continue
        # Direct file in base (e.g. /usr/share/pixmaps/foo.png)
        for ext in exts:
            direct = os.path.join(base, icon_val + ext)
            if os.path.isfile(direct):
                return direct
        # hicolor theme structure
        hicolor = os.path.join(base, "hicolor")
        if os.path.isdir(hicolor):
            for sz in preferred_sizes:
                for ext in exts:
                    cand = os.path.join(hicolor, sz, "apps", icon_val + ext)
                    if os.path.isfile(cand):
                        return cand
        # emudeck icons dir
        emudeck_dir = os.path.join(base, "emudeck")
        if os.path.isdir(emudeck_dir):
            for ext in exts:
                cand = os.path.join(emudeck_dir, icon_val + ext)
                if os.path.isfile(cand):
                    return cand

    return icon_val


def is_executable_valid(exec_cmd, try_exec=""):
    if try_exec:
        try_exec = try_exec.strip()
        if try_exec.startswith("/"):
            if not (os.path.isfile(try_exec) and os.access(try_exec, os.X_OK)):
                return False
        else:
            if not shutil.which(try_exec):
                return False

    if not exec_cmd:
        return False

    try:
        tokens = shlex.split(exec_cmd)
    except ValueError:
        tokens = exec_cmd.split()

    if not tokens:
        return False

    # Skip env assignments or wrapper prefixes
    idx = 0
    if tokens[0] in ("env", "/usr/bin/env"):
        idx += 1
        while idx < len(tokens) and "=" in tokens[idx] and not tokens[idx].startswith("-"):
            idx += 1

    if idx >= len(tokens):
        return False

    binary = os.path.expanduser(tokens[idx])
    if binary.startswith("/"):
        return os.path.isfile(binary)
    return shutil.which(binary) is not None


def parse_desktop_file(filepath):
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except OSError:
        return None

    in_desktop_entry = False
    entry = {}

    for raw_line in lines:
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            if line == "[Desktop Entry]":
                in_desktop_entry = True
                continue
            elif in_desktop_entry:
                # Reached [Desktop Action ...] or another group; stop reading
                break
            else:
                continue

        if not in_desktop_entry or "=" not in line:
            continue

        key, val = line.split("=", 1)
        key = key.strip()
        val = val.strip()
        # Keep first (unlocalized) Name/Exec/Icon unless not set yet
        if key not in entry:
            entry[key] = val

    if entry.get("Type", "Application") != "Application":
        return None
    if entry.get("NoDisplay", "").lower() == "true":
        return None
    if entry.get("Hidden", "").lower() == "true":
        return None

    name = entry.get("Name", "").strip()
    raw_exec = entry.get("Exec", "").strip()
    try_exec = entry.get("TryExec", "").strip()
    icon = entry.get("Icon", "").strip()

    if not name or not raw_exec:
        return None

    # Strip FreeDesktop field codes (%u, %f, %F, %U, etc.) and Flatpak forwarding wrappers
    cleaned_exec = FIELD_CODE_RE.sub("", raw_exec).strip()
    cleaned_exec = re.sub(r"%[a-zA-Z]", "", cleaned_exec).strip()
    cleaned_exec = re.sub(r"--file-forwarding\b", "", cleaned_exec)
    cleaned_exec = re.sub(r"@@u?\s+@@(?:\s+|$)", "", cleaned_exec)
    cleaned_exec = re.sub(r"@@\s+@@(?:\s+|$)", "", cleaned_exec)
    cleaned_exec = re.sub(r"@@(?:\s+|$)", "", cleaned_exec)
    cleaned_exec = re.sub(r"\s+--nxm(?:\s+|$)", " ", cleaned_exec)
    cleaned_exec = re.sub(r"\s+--\s*$", "", cleaned_exec).strip()
    cleaned_exec = re.sub(r"\s+", " ", cleaned_exec).strip()

    if not is_executable_valid(cleaned_exec, try_exec):
        return None

    resolved_icon = resolve_icon(icon)
    return {
        "name": name,
        "exec": cleaned_exec,
        "icon": resolved_icon,
    }


def clean_appimage_name(filename):
    base = re.sub(r"\.(AppImage|appimage)$", "", filename)
    # Strip gearlever hash or version suffix like -v1.11.2-x86_64
    if base.startswith("gearlever_"):
        base = base[len("gearlever_"):]
        base = re.sub(r"_[0-9a-f]{6,}$", "", base)
    base = re.sub(r"[-_]?v?\d+\.\d+(?:\.\d+)*(?:[-_](?:x86_64|amd64|linux|appimage))*$", "", base, flags=re.IGNORECASE)
    base = base.replace("_", " ").replace("-", " ").strip()
    if base and base.islower():
        base = base.title()
    return base or filename


def match_emudeck_or_local_icon(stem):
    stem_low = stem.lower().replace(" ", "").replace("-", "").replace("_", "")
    emudeck_icons = os.path.join(HOME, ".local/share/icons/emudeck")
    if os.path.isdir(emudeck_icons):
        for fname in os.listdir(emudeck_icons):
            fstem, ext = os.path.splitext(fname)
            if ext.lower() in (".svg", ".png") and fstem.lower().replace("-", "") in stem_low:
                return os.path.join(emudeck_icons, fname)
    return ""


def main():
    apps = []
    seen_names = set()
    known_appimage_stems = set()

    for d in DESKTOP_DIRS:
        if not os.path.isdir(d):
            continue
        for fname in sorted(os.listdir(d)):
            if not fname.endswith(".desktop"):
                continue
            fpath = os.path.join(d, fname)
            if not os.path.isfile(fpath):
                continue
            parsed = parse_desktop_file(fpath)
            if not parsed:
                continue

            norm_name = parsed["name"].lower()
            if norm_name in seen_names:
                continue
            seen_names.add(norm_name)

            # Track stems so standalone AppImages that already have a .desktop entry aren't duplicated
            clean_stem = re.sub(r"\s*\(?appimage\)?$", "", norm_name).replace(" ", "").replace("-", "")
            if clean_stem:
                known_appimage_stems.add(clean_stem)
            exec_low = parsed["exec"].lower()
            for ai_match in re.findall(r"([a-z0-9_.-]+)\.(?:appimage|sh)", exec_low):
                known_appimage_stems.add(ai_match.replace("-", "").replace("_", ""))

            apps.append(parsed)

    # Discover standalone AppImages in ~/Applications, ~/AppImages, ~/.local/bin
    for ai_dir in APPIMAGE_DIRS:
        if not os.path.isdir(ai_dir):
            continue
        for fname in sorted(os.listdir(ai_dir)):
            if not fname.lower().endswith(".appimage"):
                continue
            fpath = os.path.join(ai_dir, fname)
            if not os.path.isfile(fpath):
                continue

            display_name = clean_appimage_name(fname)
            stem_key = display_name.lower().replace(" ", "").replace("-", "").replace("_", "")
            raw_stem = re.sub(r"\.(AppImage|appimage)$", "", fname).lower().replace("-", "").replace("_", "")

            if display_name.lower() in seen_names or stem_key in known_appimage_stems or raw_stem in known_appimage_stems:
                continue

            seen_names.add(display_name.lower())
            known_appimage_stems.add(stem_key)

            try:
                st = os.stat(fpath)
                if not (st.st_mode & 0o111):
                    os.chmod(fpath, st.st_mode | 0o755)
            except OSError:
                pass

            icon = match_emudeck_or_local_icon(display_name) or resolve_icon(display_name.lower())
            apps.append({
                "name": f"{display_name} (AppImage)",
                "exec": shlex.quote(fpath),
                "icon": icon,
            })

    apps.sort(key=lambda x: x["name"].lower())
    for app in apps:
        print(f"{app['name']}\t{app['exec']}\t{app['icon']}")


if __name__ == "__main__":
    main()
