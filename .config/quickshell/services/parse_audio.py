import subprocess
import json

def get_audio_state():
    try:
        data = json.loads(subprocess.check_output(["pw-dump"], text=True))
    except Exception:
        data = []

    # Find default device names from metadata
    default_sink_name = None
    default_source_name = None

    metadata = [x for x in data if x.get("type") == "PipeWire:Interface:Metadata" and x.get("props", {}).get("metadata.name") == "default"]
    if metadata:
        meta_entries = metadata[0].get("metadata", [])
        for entry in meta_entries:
            if entry.get("key") == "default.audio.sink":
                default_sink_name = entry.get("value", {}).get("name")
            elif entry.get("key") == "default.audio.source":
                default_source_name = entry.get("value", {}).get("name")

    # Find Nodes
    sinks = []
    sources = []

    for item in data:
        if item.get("type") != "PipeWire:Interface:Node":
            continue
        
        info = item.get("info", {})
        props = info.get("props", {})
        media_class = props.get("media.class", "")
        
        if media_class not in ("Audio/Sink", "Audio/Source"):
            continue
            
        device_id = item["id"]
        name = props.get("node.name")
        desc = props.get("node.description") or props.get("node.nick") or name
        
        # Extract volume & mute
        volume = 0
        muted = False
        
        params = info.get("params", {})
        props_list = params.get("Props", [])
        for p in props_list:
            v_val = None
            if "channelVolumes" in p and p["channelVolumes"]:
                v_val = p["channelVolumes"][0]
            elif "softVolumes" in p and p["softVolumes"]:
                v_val = p["softVolumes"][0]
            elif "volume" in p:
                v_val = p["volume"]
                
            if v_val is not None:
                # Convert linear volume factor to cubic scale used by wpctl
                cubic_volume = v_val ** (1.0/3.0)
                volume = int(round(cubic_volume * 100))
                muted = p.get("mute", p.get("softMute", False))
                break
                
        is_default = False
        if media_class == "Audio/Sink":
            is_default = (name == default_sink_name)
            sinks.append({"id": device_id, "name": desc, "isDefault": is_default, "volume": volume, "muted": muted})
        else:
            is_default = (name == default_source_name)
            sources.append({"id": device_id, "name": desc, "isDefault": is_default, "volume": volume, "muted": muted})

    # Compile default nodes
    default_sink = next((x for x in sinks if x["isDefault"]), None)
    default_source = next((x for x in sources if x["isDefault"]), None)

    result = {
        "volume": default_sink["volume"] if default_sink else 50,
        "muted": default_sink["muted"] if default_sink else False,
        "sourceVolume": default_source["volume"] if default_source else 50,
        "sourceMuted": default_source["muted"] if default_source else False,
        "outputs": sinks,
        "inputs": sources
    }
    return result

if __name__ == "__main__":
    print(json.dumps(get_audio_state()))
