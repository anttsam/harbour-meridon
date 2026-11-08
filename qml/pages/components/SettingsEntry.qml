import QtQuick 2.0
import Sailfish.Silica 1.0

// A row on the Settings overview: title, optional one-line summary and a
// chevron for rows that open a page

BackgroundItem {
    id: root

    property string title
    property string subtitle
    property bool chevron: true

    width: parent ? parent.width : Screen.width
    height: subtitle.length > 0 ? Theme.itemSizeLarge : Theme.itemSizeMedium

    Column {
        anchors {
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            right: chevronIcon.visible ? chevronIcon.left : parent.right
            rightMargin: Theme.paddingMedium
            verticalCenter: parent.verticalCenter
        }

        Label {
            width: parent.width
            text: root.title
            color: root.highlighted ? Theme.highlightColor : Theme.primaryColor
            truncationMode: TruncationMode.Fade
        }

        Label {
            width: parent.width
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: root.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            font.pixelSize: Theme.fontSizeExtraSmall
            truncationMode: TruncationMode.Fade
        }
    }

    Icon {
        id: chevronIcon
        visible: root.chevron
        anchors {
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        source: "image://theme/icon-m-right"
        opacity: Theme.opacityHigh
    }
}
