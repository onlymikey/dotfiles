pragma Singleton
import QtQuick
import Quickshell

QtObject {
    // Config path retrieved dynamically from environment
    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell"
    readonly property string assetsPath: configPath + "/assets"
    
    // Profile Pictures
    readonly property string pfpsPath: assetsPath + "/pfps"
    readonly property string defaultPfp: "file://" + pfpsPath + "/pfp.jpg"
    
    // Gifs
    readonly property string gifsPath: assetsPath + "/gifs"
}
