import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../theme"

DashboardModule {
    id: powerProfileModule
    displayName: "Power Profiles"
    available: true
    implicitHeight: root.powerProfileService.supported ? 100 : 70

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // Header Row
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "Power Profile"
                color: root.walForeground
                font.pixelSize: Typography.sizeBodyMedium
                font.bold: true
                font.family: Typography.defaultFamily
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: root.powerProfileService.supported && root.powerProfileService.driver !== ""
                text: "Driver: " + root.powerProfileService.driver
                color: root.walColor8
                font.pixelSize: Typography.sizeSmall
                font.family: Typography.defaultFamily
            }
        }

        // Active state
        RowLayout {
            visible: root.powerProfileService.supported
            Layout.fillWidth: true
            spacing: Spacing.sm

            Repeater {
                model: root.powerProfileService.availableProfiles

                delegate: Rectangle {
                    id: profileCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: Radius.mediumSmall
                    
                    property bool isActive: modelData === root.powerProfileService.currentProfile
                    
                    color: isActive 
                        ? Qt.rgba(root.walColor2.r, root.walColor2.g, root.walColor2.b, 0.25)
                        : (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
                        
                    border.color: isActive ? root.walColor2 : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                    Behavior on border.color { ColorAnimation { duration: Animations.fast } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: getProfileIcon(modelData)
                            color: isActive ? root.walColor2 : root.walColor8
                            font.pixelSize: Typography.sizeTitleSmall
                            font.family: Typography.defaultFamily
                        }

                        Text {
                            text: getProfileName(modelData)
                            color: isActive ? root.walForeground : root.walColor8
                            font.pixelSize: Typography.sizeBodySmall
                            font.bold: isActive
                            font.family: Typography.defaultFamily
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.powerProfileService.setProfile(modelData)
                    }
                }
            }
        }

        // Disabled State
        RowLayout {
            visible: !root.powerProfileService.supported
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Qt.rgba(1, 1, 1, 0.02)
                radius: Radius.mediumSmall
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Spacing.sm
                    
                    Text {
                        text: Icons.notificationActive
                        color: root.walColor8
                        font.pixelSize: Typography.sizeBodyLarge
                        font.family: Typography.defaultFamily
                    }
                    Text {
                        text: "Power Profile service is unavailable"
                        color: root.walColor8
                        font.pixelSize: Typography.sizeBodySmall
                        font.family: Typography.defaultFamily
                    }
                }
            }
        }
    }

    function getProfileIcon(profile) {
        var p = profile.toLowerCase()
        if (p === "performance") return Icons.profilePerformance
        if (p === "balanced") return Icons.profileBalanced
        if (p === "power-saver" || p === "powersave" || p === "bat") return Icons.profilePowerSaver
        if (p === "ac") return Icons.profileAc
        return Icons.profileDefault
    }

    function getProfileName(profile) {
        var p = profile.toLowerCase()
        if (p === "performance") return "Performance"
        if (p === "balanced") return "Balanced"
        if (p === "power-saver") return "Power Saver"
        if (p === "powersave") return "Power Saver"
        if (p === "bat") return "Battery"
        if (p === "ac") return "AC Power"
        return profile.charAt(0).toUpperCase() + profile.slice(1)
    }
}
