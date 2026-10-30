import ctypes
import os
import sys
import select

# Load libc
try:
    libc = ctypes.CDLL(None)
except Exception:
    try:
        libc = ctypes.CDLL("libc.so.6")
    except Exception as e:
        print(f"Error loading libc: {e}", file=sys.stderr)
        sys.exit(1)

# Constants
IN_MODIFY = 0x00000002
IN_CREATE = 0x00000100
IN_DELETE = 0x00000200
IN_MOVED_FROM = 0x00000040
IN_MOVED_TO = 0x00000080
IN_CLOSE_WRITE = 0x00000008

MASK = IN_MODIFY | IN_CREATE | IN_DELETE | IN_MOVED_FROM | IN_MOVED_TO | IN_CLOSE_WRITE

# Init inotify
fd = libc.inotify_init()
if fd < 0:
    print("Error: inotify_init failed", file=sys.stderr)
    sys.exit(1)

home = os.path.expanduser("~")
candidate_paths = [
    "/usr/share/applications",
    "/usr/local/share/applications",
    "/var/lib/flatpak/exports/share/applications",
    os.path.join(home, ".local/share/flatpak/exports/share/applications"),
    os.path.join(home, ".local/share/applications"),
    os.path.join(home, "Applications"),
]

user_apps = os.path.join(home, ".local/share/applications")
if not os.path.exists(user_apps):
    try:
        os.makedirs(user_apps, exist_ok=True)
    except Exception:
        pass

wds = {}
for p in candidate_paths:
    if os.path.isdir(p):
        wd = libc.inotify_add_watch(fd, p.encode("utf-8"), MASK)
        if wd >= 0:
            wds[wd] = p

print("APPS_WATCHER_READY", flush=True)

while True:
    try:
        r, _, _ = select.select([fd], [], [])
        if fd in r:
            data = os.read(fd, 4096)
            if not data:
                break
            print("change", flush=True)
    except KeyboardInterrupt:
        break
    except Exception as e:
        print(f"Error in select loop: {e}", file=sys.stderr)
        break
