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

# Paths to watch
paths = ["/usr/share/applications"]
user_apps = os.path.expanduser("~/.local/share/applications")

# Ensure user directory exists so we can watch it
if not os.path.exists(user_apps):
    try:
        os.makedirs(user_apps, exist_ok=True)
    except Exception:
        pass

if os.path.exists(user_apps):
    paths.append(user_apps)

# Add watches
wds = {}
for p in paths:
    wd = libc.inotify_add_watch(fd, p.encode('utf-8'), MASK)
    if wd >= 0:
        wds[wd] = p
    else:
        print(f"Warning: could not watch {p}", file=sys.stderr)

print("APPS_WATCHER_READY", flush=True)

# Select loop to wait for events
while True:
    try:
        r, _, _ = select.select([fd], [], [])
        if fd in r:
            data = os.read(fd, 4096)
            if not data:
                break
            # Signal a change to Quickshell
            print("change", flush=True)
    except KeyboardInterrupt:
        break
    except Exception as e:
        print(f"Error in select loop: {e}", file=sys.stderr)
        break
