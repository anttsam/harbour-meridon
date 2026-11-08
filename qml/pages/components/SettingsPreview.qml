import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib

// A made-up post drawn with the same font, size, spacing and highlight
// settings the feed uses, so the Appearance page shows what a change does
// without leaving it. Purely visual: no model, no network.

Item {
    id: root

    width: parent ? parent.width : Screen.width
    height: card.height + Theme.paddingLarge

    Rectangle {
        id: card
        x: Theme.horizontalPageMargin
        y: Theme.paddingSmall
        width: parent.width - 2 * Theme.horizontalPageMargin
        height: content.height + 2 * Theme.paddingMedium
        radius: Theme.paddingSmall
        color: Theme.rgba(Theme.primaryColor, 0.06)

        Row {
            id: content
            x: Theme.paddingMedium
            y: Theme.paddingMedium
            width: card.width - 2 * Theme.paddingMedium
            spacing: Theme.paddingMedium

            RoundedAvatar {
                size: Theme.iconSizeMedium
                source: Qt.resolvedUrl("../../images/harbour-meridon.png")
            }

            Column {
                width: parent.width - Theme.iconSizeMedium - parent.spacing
                spacing: Theme.paddingSmall

                Row {
                    spacing: Theme.paddingSmall
                    width: parent.width

                    AppLabel {
                        id: nameLabel
                        text: qsTr("Meridon")
                        useCustomFont: true
                        bold: true
                        font.pixelSize: Theme.fontSizeSmall * sizeMultiplier
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    AppLabel {
                        text: "@meridon · 2h"
                        useCustomFont: true
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                        truncationMode: TruncationMode.Fade
                        width: Math.min(contentWidth, parent.width - nameLabel.width - parent.spacing)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                AppLabel {
                    width: parent.width
                    text: AppLib.EmojiManager.render(
                        qsTr("Reading the fediverse on Sailfish OS looks like this.")
                            + " <a href=\"#\">#sailfishos</a> 🙂",
                        "{}", Theme.fontSizeSmall * sizeMultiplier)
                    textFormat: Text.RichText
                    useCustomFont: true
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall * sizeMultiplier
                    color: Theme.primaryColor
                    linkColor: palette.secondaryHighlightColor
                }

                Row {
                    spacing: Theme.paddingLarge * 1.5
                    opacity: 0.5

                    Image {
                        source: "image://theme/icon-s-chat"
                        width: Theme.iconSizeSmall * 1.2
                        height: width
                    }
                    Image {
                        source: "image://theme/icon-s-retweet"
                        width: Theme.iconSizeSmall * 1.2
                        height: width
                    }
                    Image {
                        source: "image://theme/icon-s-like?" + AppLib.BackgroundManager.activeHighlightColor
                        width: Theme.iconSizeSmall * 1.2
                        height: width
                    }
                }
            }
        }
    }
}
