import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib

// Compact feed name strip, sitting above the swipeable feed carousel

Item {
    id: feedTabStrip

    property alias model: stripView.model
    property alias currentIndex: stripView.currentIndex

    property bool isPortrait: true

    readonly property real topCutoutMargin: (isPortrait && Screen.topCutout.height > 0)
        ? Math.max(0, Screen.topCutout.height - Theme.paddingMedium)
        : 0

    height: Theme.itemSizeSmall + topCutoutMargin

    SilicaListView {
        id: stripView
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: Theme.itemSizeSmall
        orientation: ListView.Horizontal
        clip: true

        // ApplyRange (not StrictlyEnforceRange)
        highlightRangeMode: ListView.ApplyRange
        // Centers on the *current* delegate's own width
        preferredHighlightBegin: width / 2 - (currentItem ? currentItem.width / 2 : 0)
        preferredHighlightEnd: width / 2 + (currentItem ? currentItem.width / 2 : 0)
        highlightMoveDuration: 200

        delegate: Item {
            id: nameDelegate
            width: label.implicitWidth + 2 * Theme.paddingMedium
            height: stripView.height

            readonly property bool isCurrent: index === stripView.currentIndex

            AppLabel {
                useCustomFont: true
                id: label
                anchors.centerIn: parent
                text: model.displayName
                font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                font.bold: nameDelegate.isCurrent
                color: nameDelegate.isCurrent ? palette.secondaryHighlightColor : Theme.secondaryColor
            }

            Rectangle {
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
                width: parent.width * 0.6
                height: Theme.paddingSmall / 4
                color: AppLib.BackgroundManager.activeHighlightColor
                visible: nameDelegate.isCurrent
            }

            MouseArea {
                anchors.fill: parent
                onClicked: stripView.currentIndex = index
            }
        }
    }
}
