#!/bin/bash
# Scale ONLY for Quickshell (Qt)
export QT_SCALE_FACTOR=1.25
export QT_AUTO_SCREEN_SCALE_FACTOR=0

# Opcional: mejora consistencia de escalado en Qt apps
export QT_ENABLE_HIGHDPI_SCALING=1
pkill quickshell; nohup quickshell &>/dev/null &
