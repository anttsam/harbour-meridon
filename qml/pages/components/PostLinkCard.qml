import QtQuick 2.0
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0

// Preview card for a status's external link (Mastodon's card.* fields)

Rectangle {
    id: postLinkCard

    property var link: null

    visible: link !== null
    height: linkColumn.height + Theme.paddingMedium
    radius: Theme.paddingMedium
    color: Theme.rgba(Theme.primaryColor, 0.06)
    border.color: Theme.rgba(Theme.primaryColor, 0.15)
    border.width: 1
    clip: true

    Column {
        id: linkColumn
        anchors.top: parent.top
        //anchors.topMargin: linkThumbContainer.visible ? 0 : Theme.paddingMedium // need spacing if no thumb
        x: 0
        width: parent.width
        spacing: Theme.paddingSmall

        Item {
            id: linkThumbContainer
            width: parent.width
            height: parent.width * 0.5
            visible: postLinkCard.link && postLinkCard.link.thumbUrl.length > 0

            Image {
                id: linkThumbImage
                anchors.fill: parent
                source: postLinkCard.link ? postLinkCard.link.thumbUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false // only rendered as OpacityMask's source below

                onStatusChanged: {
                    if (status === Image.Error)
                        console.warn("[PostLinkCard] link thumb decode failed:", postLinkCard.link.thumbUrl)
                }
            }

            // Opcity mask to make cards corners round
            Item {
                id: linkThumbMask
                anchors.fill: parent
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.paddingMedium
                }
                // but cut the bottom straight
                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: Theme.paddingMedium
                }
            }

            OpacityMask {
                anchors.fill: linkThumbImage
                source: linkThumbImage
                maskSource: linkThumbMask
            }
        }
        Item { //add extra spacing
            id: thumbPlaceholder
            height: 1
            width:1
        }

        AppLabel {
            x: Theme.paddingMedium
            width: parent.width - 2 * Theme.paddingMedium
            visible: postLinkCard.link && postLinkCard.link.title.length > 0
            text: postLinkCard.link ? postLinkCard.link.title : ""
            wrapMode: Text.Wrap
            maximumLineCount: 2
            truncationMode: TruncationMode.Fade
            font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
            bold: true
            color: Theme.primaryColor
            useCustomFont: true //try if this is ok for scrolling performance
        }

        AppLabel {
            x: Theme.paddingMedium
            width: parent.width - 2 * Theme.paddingMedium
            visible: postLinkCard.link && postLinkCard.link.description.length > 0
            text: postLinkCard.link ? postLinkCard.link.description : ""
            wrapMode: Text.Wrap
            maximumLineCount: 2
            truncationMode: TruncationMode.Fade
            font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
            color: Theme.primaryColor
            useCustomFont: true //try if this is ok for scrolling performance
        }

        AppLabel {
            x: Theme.paddingMedium
            width: parent.width - 2 * Theme.paddingMedium
            visible: postLinkCard.link && postLinkCard.link.domain.length > 0
            text: postLinkCard.link ? postLinkCard.link.domain : ""
            truncationMode: TruncationMode.Fade
            font.pixelSize: (Theme.fontSizeExtraSmall - 4) * sizeMultiplier
            color: Theme.secondaryColor
            opacity: 0.6
            height: contentHeight - parent.spacing  // tidy up the height of the column
            useCustomFont: true //try if this is ok for scrolling performance
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (postLinkCard.link)
                pageStack.push(Qt.resolvedUrl("../WebViewPage.qml"), {
                    url: postLinkCard.link.uri
                })
        }
    }
}
