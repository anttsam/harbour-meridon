import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib
import "../../lib/PostMapper.js" as PostMapper

// The action bar under a post: reply/repost/like etc

Item {
    id: statsRowWrapper

    property int replyCount: 0
    property int repostCount: 0
    property int likeCount: 0
    property bool favourited: false
    property bool reblogged: false
    property bool bookmarked: false

    signal replyRequested()
    signal repostToggled()
    signal likeToggled()
    signal bookmarkToggled()
    signal moreRequested()

    width: parent ? parent.width : 0
    height: Theme.itemSizeExtraSmall * 0.6 //statsRow.height
    opacity: 0.5

    Row {
        id: statsRow
        spacing: Theme.paddingLarge * 1.5
        anchors.verticalCenter: parent.verticalCenter

        Item {
            id: replyContainer
            width: statsRowWrapper.width / 6 //replyRow.width + Theme.paddingMedium
            anchors.verticalCenter: parent.verticalCenter
            height: replyRow.height

            Row {
                id: replyRow
                //anchors.centerIn: parent
                spacing: Theme.paddingSmall
                Image { source: "image://theme/icon-s-chat"; width: Theme.iconSizeSmall; height: width; anchors.verticalCenter: parent.verticalCenter }
                AppLabel { text: PostMapper.formatCount(statsRowWrapper.replyCount); font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier; color: Theme.secondaryColor; anchors.verticalCenter: parent.verticalCenter }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: statsRowWrapper.replyRequested()
            }
        }

        Item {
            id: repostContainer
            width: statsRowWrapper.width / 6
            //width: repostRow.width + Theme.paddingMedium
            anchors.verticalCenter: parent.verticalCenter
            height: repostRow.height


            Row {
                id: repostRow
                //anchors.centerIn: parent
                spacing: Theme.paddingSmall

                Image {
                    source: "image://theme/icon-s-retweet?"
                        + (statsRowWrapper.reblogged ? AppLib.BackgroundManager.activeHighlightColor : Theme.secondaryColor)
                    width: Theme.iconSizeSmall
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                }
                AppLabel {
                    text: PostMapper.formatCount(statsRowWrapper.repostCount)
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                    color: statsRowWrapper.reblogged ? palette.highlightColor : Theme.secondaryColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: statsRowWrapper.repostToggled()
            }
        }

        Item {
            id: likeContainer
            width: statsRowWrapper.width / 6 //likeRow.width + Theme.paddingMedium // a bit of extra tap-target padding
            anchors.verticalCenter: parent.verticalCenter
            height: likeRow.height

            Row {
                id: likeRow
                //anchors.centerIn: parent
                spacing: Theme.paddingSmall

                Image {
                    source: "image://theme/icon-s-like?"
                        + (statsRowWrapper.favourited ? AppLib.BackgroundManager.activeHighlightColor : Theme.secondaryColor)
                    width: Theme.iconSizeSmall
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                }
                AppLabel {
                    text: PostMapper.formatCount(statsRowWrapper.likeCount)
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                    color: statsRowWrapper.favourited ? palette.highlightColor : Theme.secondaryColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: statsRowWrapper.likeToggled()
            }
        }

        Item {
            id: bookmarkContainer
            width: statsRowWrapper.width / 6
            anchors.verticalCenter: parent.verticalCenter
            height: bookmarkRow.height

            Row {
                id: bookmarkRow
                spacing: Theme.paddingSmall

                // No dedicated bookmark icon in the Silica theme - the
                // incognito icon's ribbon/ghost shape reads as a bookmark
                // once flipped upside down (rotation: 180), with the same
                // "new"/"selected" (outline/filled) pair every other
                // stateful theme icon already provides.
                Image {
                    source: "image://theme/icon-m-incognito-" + (statsRowWrapper.bookmarked ? "selected" : "new") + "?"
                        + (statsRowWrapper.bookmarked ? AppLib.BackgroundManager.activeHighlightColor : Theme.secondaryColor)
                    width: likeContainer.height //Theme.iconSizeMedium
                    height: width
                    rotation: 180
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: statsRowWrapper.bookmarkToggled()
            }
        }
    }

    Rectangle {
        id: moreButton
        width: moreMenu.width * 2
        height: statsRow.height * 1.2
        color: moreMenuArea.pressed ? AppLib.BackgroundManager.activeHighlightColor : "transparent"
        radius: 10
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        AppLabel {
            id: moreMenu
            text: "···" //"". . ."
            font.pixelSize: (Theme.fontSizeMedium) * sizeMultiplier
            bold: true
            color: Theme.secondaryColor
            anchors.verticalCenter: parent.verticalCenter
            //anchors.verticalCenterOffset: -statsRow.height / 3
            anchors.horizontalCenter: parent.horizontalCenter
            //anchors.right: parent.right
        }

        MouseArea {
            id: moreMenuArea
            anchors.fill: parent
            onClicked: statsRowWrapper.moreRequested()
        }
    }
}
