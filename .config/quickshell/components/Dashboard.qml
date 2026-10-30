import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "./modules"
import "../theme"

/**
 * Dashboard Panel - Modular Architecture
 *
 * The dashboard is now an orchestrator that renders available modules.
 * Each module is self-describing with an 'available' property.
 *
 * This design allows:
 * - Same config on desktop and laptop
 * - Automatic hardware capability detection
 * - Easy addition of new modules
 * - No hardware conditionals in the dashboard itself
 */
PanelWindow {
    id: dashboard
    screen: root.panelScreen
    visible: root.dashboardVisible || slideAnim.running
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    anchors { top: true; bottom: true; right: true }
    margins { top: 40; bottom: 10; right: root.dashboardVisible ? 6 : -Math.round(460 * UIScale.scale) }
    implicitWidth: Math.round(420 * UIScale.scale)
    color: "transparent"
    focusable: true
    WlrLayershell.keyboardFocus: root.dashboardVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Behavior on margins.right { NumberAnimation { id: slideAnim; duration: Animations.normal; easing.type: Easing.OutCubic } }

    Connections {
        target: root
        function onDashboardVisibleChanged() {
            if (root.dashboardVisible) {
                Qt.callLater(() => dashFocusAnchor.forceActiveFocus())
            }
        }
    }

    FocusScope {
        id: dashFocusScope
        anchors.fill: parent
        focus: root.dashboardVisible
        enabled: root.dashboardVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.closeAllPanels()
                event.accepted = true
            }
        }

        Item {
            id: dashFocusAnchor
            focus: true
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.7)
            radius: Radius.panel

            Flickable {
                id: flickable
                anchors.fill: parent
                anchors.margins: 20
                contentHeight: mainLayout.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                ScrollBar.vertical: ScrollBar {
                    parent: flickable.parent
                    anchors.right: flickable.right
                    anchors.rightMargin: -10
                    anchors.top: flickable.top
                    anchors.bottom: flickable.bottom
                    active: flickable.moving || flickable.flicking
                    policy: ScrollBar.AsNeeded
                }

                ColumnLayout {
                    id: mainLayout
                    width: parent.width
                    spacing: 15

                    /**
                     * Module Instantiation
                     *
                     * All modules are instantiated directly in the layout.
                     * Each module controls its own visibility via the 'available' property.
                     * This ensures proper layout behavior in ColumnLayout.
                     */
                    ProfileModule {
                        visible: available
                    }

                    PowerButtonsModule {
                        visible: available
                    }

                    BatteryModule {
                        visible: available
                    }

                    PowerProfileModule {
                        visible: available
                    }

                    SystemStatsModule {
                        visible: available
                    }

                    AudioModule {
                        visible: available
                    }

                    ClockModule {
                        visible: available
                    }
                }
            }
        }
    }
}
