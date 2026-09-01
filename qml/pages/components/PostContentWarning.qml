import QtQuick 2.0
import Sailfish.Silica 1.0

// Content warning banner for PostDelegate.qml

Rectangle {
    id: warningCard

    property string text: ""
    property bool revealed: false

    signal toggleRequested()

    visible: warningCard.text.length > 0
    height: visible ? Math.max(showButton.height, contentRow.height) + 2 * Theme.paddingMedium : 0
    radius: Theme.paddingMedium
    color: Theme.rgba(Theme.primaryColor, 0.06)
    border.color: Theme.rgba(palette.highlightColor, 0.35)
    border.width: 1

    Row {
        id: contentRow
        //width: parent.width
        spacing: Theme.paddingMedium
        anchors {
            top: parent.top
            left: parent.left
            right: showButton.left
            margins: Theme.paddingMedium
        }

        Icon {
            source: "image://theme/icon-m-warning"
            width: Theme.iconSizeSmall
            height: width
            color: palette.highlightColor
        }

        AppLabel {
            text: warningCard.text
            wrapMode: Text.Wrap
            width: parent.width - Theme.iconSizeSmall - parent.spacing
            font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
            color: Theme.primaryColor
            useCustomFont: true
        }



    }
    SecondaryButton {
        id: showButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.paddingMedium
        text: warningCard.revealed ? qsTr("Hide") : qsTr("Show")
        preferredWidth: Theme.buttonWidthTiny
        onClicked: warningCard.toggleRequested()
    }
}
