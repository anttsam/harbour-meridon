import QtQuick 2.0
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0

Item {
    id: root

    property alias source: avatarImage.source
    property int size: Theme.iconSizeMedium
    property string fallbackSource: "image://theme/icon-m-contact"
    property int roundRadius: 8
    property bool showBorder: true
    property bool shadow: false
    property real shadowRadius: 8
    property color shadowColor: Theme.overlayBackgroundColor //Theme.rgba(Theme.primaryColor, 0.4)

    width: size
    height: size

    // loader gated glow
    Loader {
        anchors.fill: parent
        active: root.shadow
        sourceComponent: active ? glowComponent : undefined
    }
    Component {
        id: glowComponent

        RectangularGlow {
            anchors.fill: parent
            glowRadius: root.shadowRadius
            spread: 0.3
            color: root.shadowColor
            cornerRadius: width / root.roundRadius
            opacity: 0.5
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: showBorder ? shadow ? 0 : -2 : 0
        radius: width / roundRadius
        color: Theme.overlayBackgroundColor
    }

    Image {
        id: avatarImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
        // Caps decode to what's actually shown - avatars can come back from
        // the server much larger than root.size, and without this Qt decodes
        // at the source's native resolution before scaling down for display.
        sourceSize.width: root.size
        sourceSize.height: root.size
        visible: false // OpacityMask

        onStatusChanged: {
            if (status === Image.Error && source != root.fallbackSource)
                source = root.fallbackSource
        }
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: width / roundRadius
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        source: avatarImage
        maskSource: mask
    }
}
