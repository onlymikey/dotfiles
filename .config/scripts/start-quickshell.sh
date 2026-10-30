#!/bin/bash
# Scale ONLY for Quickshell (Qt) - UIScale.qml & Typography.qml handle adaptive per-monitor scaling
export QT_SCALE_FACTOR=1
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export QT_ENABLE_HIGHDPI_SCALING=0
export QT_FONT_DPI=96

pkill quickshell; nohup quickshell &>/dev/null &
