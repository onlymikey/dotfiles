#!/usr/bin/env python3
import subprocess
import json
import os
import sys
import socket

def get_proc_cmdline(pid):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            content = f.read()
        parts = [p.decode('utf-8', errors='ignore') for p in content.split(b'\0') if p]
        return parts
    except Exception:
        return None

def capture_session():
    # 1. Query hyprctl clients
    res = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True)
    if res.returncode != 0:
        print("Error: hyprctl failed", file=sys.stderr)
        sys.exit(1)
        
    try:
        clients = json.loads(res.stdout)
    except Exception as e:
        print(f"Error parsing JSON: {e}", file=sys.stderr)
        sys.exit(1)
        
    session_windows = []
    for client in clients:
        # Ignore special or empty workspaces, and ignore quickshell itself
        ws_id = client.get("workspace", {}).get("id", 0)
        if client.get("class") == "quickshell":
            continue
            
        pid = client.get("pid")
        cmdline = get_proc_cmdline(pid) if pid else None
        
        if not cmdline:
            continue
            
        at = client.get("at", [0, 0])
        size = client.get("size", [0, 0])
        
        win_data = {
            "exec": cmdline,
            "class": client.get("class"),
            "workspace": ws_id,
            "monitor": client.get("monitor", 0),
            "floating": client.get("floating", False),
            "fullscreen": client.get("fullscreen", 0) != 0,
            "geometry": {
                "x": at[0],
                "y": at[1],
                "width": size[0],
                "height": size[1]
            }
        }
        session_windows.append(win_data)
        
    state_path = os.path.expanduser("~/.config/quickshell/state")
    os.makedirs(state_path, exist_ok=True)
    session_file = os.path.join(state_path, "session.json")
    
    with open(session_file, "w") as f:
        json.dump(session_windows, f, indent=4)
        
    print("Session captured successfully.")

def find_hyprland_socket():
    uid = os.getuid()
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if sig:
        path = f"/run/user/{uid}/hypr/{sig}/.socket2.sock"
        if os.path.exists(path):
            return path
        path = f"/tmp/hypr/{sig}/.socket2.sock"
        if os.path.exists(path):
            return path
            
    # Fallback search
    for root_dir in [f"/run/user/{uid}/hypr", "/tmp/hypr"]:
        if os.path.exists(root_dir):
            for d in os.listdir(root_dir):
                path = os.path.join(root_dir, d, ".socket2.sock")
                if os.path.exists(path):
                    return path
    return None

def restore_window_state(addr, win):
    win_ref = f"address:0x{addr}"
    ws = win.get("workspace")
    floating = win.get("floating", False)
    fullscreen = win.get("fullscreen", False)
    geom = win.get("geometry", {})
    
    # 1. Move to workspace
    if ws is not None:
        subprocess.run(["hyprctl", "dispatch", "movetoworkspace", f"{ws},{win_ref}"], stdout=subprocess.DEVNULL)
        
    # 2. Set floating / geometry
    if floating:
        subprocess.run(["hyprctl", "dispatch", "setfloating", win_ref], stdout=subprocess.DEVNULL)
        x = geom.get("x", 100)
        y = geom.get("y", 100)
        w = geom.get("width", 800)
        h = geom.get("height", 600)
        subprocess.run(["hyprctl", "dispatch", "movewindowpixel", f"exact {x} {y},{win_ref}"], stdout=subprocess.DEVNULL)
        subprocess.run(["hyprctl", "dispatch", "resizewindowpixel", f"exact {w} {h},{win_ref}"], stdout=subprocess.DEVNULL)
    else:
        subprocess.run(["hyprctl", "dispatch", "settiled", win_ref], stdout=subprocess.DEVNULL)
        
    # 3. Set fullscreen
    if fullscreen:
        subprocess.run(["hyprctl", "dispatch", "setfullscreen", f"1,{win_ref}"], stdout=subprocess.DEVNULL)

def restore_session():
    state_path = os.path.expanduser("~/.config/quickshell/state")
    session_file = os.path.join(state_path, "session.json")
    if not os.path.exists(session_file):
        print("No saved session found.")
        return

    with open(session_file, "r") as f:
        try:
            saved_windows = json.load(f)
        except Exception:
            print("Error reading session file.")
            return

    if not saved_windows:
        print("Saved session is empty.")
        return

    pending = {}
    for win in saved_windows:
        cls = win.get("class")
        if cls:
            if cls not in pending:
                pending[cls] = []
            pending[cls].append(win)

    # Launch applications
    launched_cmds = set()
    for win in saved_windows:
        cmd = win.get("exec")
        if cmd:
            cmd_key = " ".join(cmd)
            if cmd_key not in launched_cmds:
                launched_cmds.add(cmd_key)
                try:
                    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                except Exception as e:
                    print(f"Failed to launch {' '.join(cmd)}: {e}")

    sock_path = find_hyprland_socket()
    if not sock_path:
        print("Error: Could not locate Hyprland socket2.sock")
        return

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(sock_path)
    except Exception as e:
        print(f"Error connecting to socket: {e}")
        return

    s.settimeout(15.0)
    buffer = ""
    
    print("Restore engine active, matching windows...")
    
    while any(pending.values()):
        try:
            data = s.recv(4096)
            if not data:
                break
            buffer += data.decode('utf-8', errors='ignore')
            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                line = line.strip()
                if ">>" in line:
                    event, args_str = line.split(">>", 1)
                    if event == "openwindow":
                        parts = [p.strip() for p in args_str.split(",")]
                        if len(parts) >= 3:
                            addr = parts[0]
                            ws = parts[1]
                            win_class = parts[2]
                            
                            if win_class in pending and pending[win_class]:
                                win = pending[win_class].pop(0)
                                restore_window_state(addr, win)
                                if not pending[win_class]:
                                    del pending[win_class]
        except socket.timeout:
            print("Restore timeout reached. Exiting.")
            break
        except Exception as e:
            print(f"Error in restore loop: {e}")
            break
            
    s.close()
    print("Session restore complete.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: session_helper.py [capture|restore]")
        sys.exit(1)
        
    action = sys.argv[1]
    if action == "capture":
        capture_session()
    elif action == "restore":
        restore_session()
    else:
        print(f"Unknown action: {action}")
        sys.exit(1)
