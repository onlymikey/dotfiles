import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../theme"

/**
 * Base component for all dashboard modules.
 *
 * Modules should expose:
 * - available: bool - whether this module should be displayed
 * - displayName: string - human-readable name for debugging
 *
 * Modules are rendered only when available=true.
 * This allows capability detection instead of hardware conditionals.
 */
Rectangle {
    id: module

    /**
     * Whether this module should be displayed.
     * Subclasses override this based on hardware detection.
     */
    property bool available: true

    /**
     * Human-readable name for this module.
     * Used for debugging and logging.
     */
    property string displayName: "Dashboard Module"

    /**
     * Visual appearance common to all modules.
     */
    color: Qt.rgba(0, 0, 0, 0.3)
    radius: 15

    /**
     * Default layout properties
     */
    Layout.fillWidth: true
}
