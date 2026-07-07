#!/usr/bin/env python3
import subprocess
import json
import os
import sys
import socket
import time
import shlex

def get_proc_cmdline(pid):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            content = f.read()
        parts = [p.decode('utf-8', errors='ignore') for p in content.split(b'\0') if p]
        return parts
    except Exception:
        return None

def find_hyprland_socket(name=".socket2.sock"):
    uid = os.getuid()
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if sig:
        for base in [f"/run/user/{uid}/hypr", "/tmp/hypr"]:
            path = os.path.join(base, sig, name)
            if os.path.exists(path):
                return path
            
    # Fallback search: find the most recent socket directory by mtime
    candidates = []
    for root_dir in [f"/run/user/{uid}/hypr", "/tmp/hypr"]:
        if os.path.exists(root_dir):
            for d in os.listdir(root_dir):
                path = os.path.join(root_dir, d, name)
                if os.path.exists(path):
                    try:
                        mtime = os.path.getmtime(path)
                        candidates.append((mtime, path))
                    except Exception:
                        pass
    if candidates:
        # Sort by mtime descending (most recent first)
        candidates.sort(key=lambda x: x[0], reverse=True)
        return candidates[0][1]
    return None

def hyprland_command(cmd_str):
    path = find_hyprland_socket(".socket.sock")
    if not path:
        print("Error: Could not locate Hyprland primary socket.sock", file=sys.stderr)
        return None
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(path)
        s.sendall(cmd_str.encode('utf-8'))
        resp = b""
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            resp += chunk
        s.close()
        return resp.decode('utf-8', errors='ignore')
    except Exception as e:
        print(f"Socket error on {path}: {e}", file=sys.stderr)
    return None

def dispatch_lua(expr):
    cmd = f"/dispatch {expr}"
    return hyprland_command(cmd)

def get_window_pid(addr):
    if not addr.startswith("0x"):
        addr = "0x" + addr
    try:
        clients_json = hyprland_command("j/clients")
        if clients_json:
            clients = json.loads(clients_json)
            for c in clients:
                if c.get("address") == addr:
                    return c.get("pid")
    except Exception as e:
        print(f"Error getting PID for {addr}: {e}", file=sys.stderr)
    return None

def get_ancestors(pid):
    ancestors = []
    curr = pid
    while curr > 1:
        try:
            with open(f"/proc/{curr}/stat", "r") as f:
                stat = f.read().split()
            ppid = int(stat[3])
            if ppid <= 1:
                break
            ancestors.append(ppid)
            curr = ppid
        except Exception:
            break
    return ancestors

def capture_session():
    clients_json = hyprland_command("j/clients")
    if not clients_json:
        print("Error: Failed to query clients", file=sys.stderr)
        sys.exit(1)
        
    try:
        clients = json.loads(clients_json)
    except Exception as e:
        print(f"Error parsing JSON: {e}", file=sys.stderr)
        sys.exit(1)
        
    session_windows = []
    for client in clients:
        # Ignore quickshell itself
        if client.get("class") == "quickshell":
            continue
            
        pid = client.get("pid")
        cmdline = get_proc_cmdline(pid) if pid else None
        
        if not cmdline:
            continue
            
        # Get workspace name (which handles special/named/normal workspaces identically!)
        ws_name = client.get("workspace", {}).get("name", "1")
        at = client.get("at", [0, 0])
        size = client.get("size", [0, 0])
        
        win_data = {
            "exec": cmdline,
            "class": client.get("class"),
            "title": client.get("title", ""),
            "initialTitle": client.get("initialTitle", ""),
            "workspace": ws_name,
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

def restore_window_state(addr, win):
    if not addr.startswith("0x"):
        addr = "0x" + addr
    win_ref = f"address:{addr}"
    ws = win.get("workspace")
    floating = win.get("floating", False)
    fullscreen = win.get("fullscreen", False)
    geom = win.get("geometry", {})
    
    # 1. Move to workspace (using name as a string)
    if ws is not None:
        dispatch_lua(f"hl.dsp.window.move({{ workspace = \"{ws}\", window = \"{win_ref}\" }})")
        
    # 2. Set floating / geometry
    if floating:
        dispatch_lua(f"hl.dsp.window.float({{ action = \"set\", window = \"{win_ref}\" }})")
        x = geom.get("x", 100)
        y = geom.get("y", 100)
        w = geom.get("width", 800)
        h = geom.get("height", 600)
        dispatch_lua(f"hl.dsp.window.move({{ x = {x}, y = {y}, window = \"{win_ref}\" }})")
        dispatch_lua(f"hl.dsp.window.resize({{ x = {w}, y = {h}, window = \"{win_ref}\" }})")
    else:
        dispatch_lua(f"hl.dsp.window.float({{ action = \"unset\", window = \"{win_ref}\" }})")
        
    # 3. Set fullscreen
    if fullscreen:
        dispatch_lua(f"hl.dsp.window.fullscreen_state({{ internal = 2, client = 0, window = \"{win_ref}\" }})")

def restore_session(force=False):
    # Find active signature
    sock_path = find_hyprland_socket(".socket.sock")
    if sock_path:
        sig = os.path.basename(os.path.dirname(sock_path))
    else:
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or "default"
        
    # Check flag file to prevent restoring multiple times in the same login session
    xdg_runtime_dir = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    quickshell_runtime_dir = os.path.join(xdg_runtime_dir, "quickshell")
    os.makedirs(quickshell_runtime_dir, exist_ok=True)
    flag_file = os.path.join(quickshell_runtime_dir, f"session_restored_{sig}")
    
    if os.path.exists(flag_file) and not force:
        print("Session already restored in this Hyprland instance. Skipping.")
        return

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

    # Map from launched PID to window data
    pid_to_window = {}
    
    # Map from class to list of pending windows
    pending_by_class = {}
    for win in saved_windows:
        cls = win.get("class")
        if cls:
            if cls not in pending_by_class:
                pending_by_class[cls] = []
            pending_by_class[cls].append(win)

    # Launch applications
    for win in saved_windows:
        cmd = win.get("exec")
        if cmd:
            launch_cmd = cmd
            if len(launch_cmd) == 1:
                launch_cmd = shlex.split(launch_cmd[0])
            try:
                proc = subprocess.Popen(launch_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                pid_to_window[proc.pid] = win
            except Exception as e:
                print(f"Failed to launch {' '.join(cmd)}: {e}")

    sock_path_2 = find_hyprland_socket(".socket2.sock")
    if not sock_path_2:
        print("Error: Could not locate Hyprland socket2.sock")
        return

    # Write flag file so that future quickshell restarts in this Hyprland instance skip auto-restore
    try:
        with open(flag_file, "w") as f:
            f.write("1")
    except Exception as e:
        print(f"Warning: Failed to create session restore flag file: {e}")

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(sock_path_2)
    except Exception as e:
        print(f"Error connecting to socket: {e}")
        return

    s.settimeout(15.0)
    buffer = ""
    
    print("Restore engine active, matching windows...")
    
    def remove_from_pending(w):
        c = w.get("class")
        if c in pending_by_class:
            if w in pending_by_class[c]:
                pending_by_class[c].remove(w)
            if not pending_by_class[c]:
                del pending_by_class[c]

    while any(pending_by_class.values()):
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
                            win_title = parts[3] if len(parts) >= 4 else ""
                            
                            matched_win = None
                            
                            # 1. Try exact PID/parent matching first
                            win_pid = get_window_pid(addr)
                            if win_pid is not None:
                                candidates = [win_pid] + get_ancestors(win_pid)
                                for cand in candidates:
                                    if cand in pid_to_window:
                                        matched_win = pid_to_window[cand]
                                        del pid_to_window[cand]
                                        remove_from_pending(matched_win)
                                        break
                                        
                            # 2. Try Class + Title matching
                            if not matched_win and win_class in pending_by_class:
                                for i, w in enumerate(pending_by_class[win_class]):
                                    saved_title = w.get("title", "")
                                    saved_init_title = w.get("initialTitle", "")
                                    if (saved_title and (saved_title in win_title or win_title in saved_title)) or \
                                       (saved_init_title and (saved_init_title in win_title or win_title in saved_init_title)):
                                        matched_win = pending_by_class[win_class].pop(i)
                                        break
                                        
                            # 3. Fallback: pop first window of this class
                            if not matched_win and win_class in pending_by_class:
                                matched_win = pending_by_class[win_class].pop(0)
                                
                            if win_class in pending_by_class and not pending_by_class[win_class]:
                                del pending_by_class[win_class]
                                
                            if matched_win:
                                restore_window_state(addr, matched_win)
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
        print("Usage: session_helper.py [capture|restore] [--force]")
        sys.exit(1)
        
    action = sys.argv[1]
    force = "--force" in sys.argv
    if action == "capture":
        capture_session()
    elif action == "restore":
        restore_session(force=force)
    else:
        print(f"Unknown action: {action}")
        sys.exit(1)
