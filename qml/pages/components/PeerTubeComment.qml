import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib
import "../../lib/PostMapper.js" as PostMapper

// One row of PeerTubePage's comment list. Replies are indented by depth, up
// to a cap so deep threads still leave room for text.

Item {
    id: peerTubeComment

    property int depth: 0
    property string html: ""
    property bool isDeleted: false
    property string authorName: ""
    property string authorHandle: ""
    property string avatarUrl: ""
    property string createdAt: ""
    property int totalReplies: 0
    property bool repliesLoaded: false
    property bool repliesBusy: false

    signal showReplies()
    signal linkClicked(string link)

    readonly property real indent: Math.min(depth, 3) * Theme.paddingLarge * 1.5

    width: parent ? parent.width : 0
    height: contentColumn.height + Theme.paddingLarge

    RoundedAvatar {
        id: avatar
        x: Theme.horizontalPageMargin + peerTubeComment.indent
        y: Theme.paddingSmall
        size: Theme.iconSizeSmall
        source: peerTubeComment.avatarUrl
        showBorder: false
    }

    Column {
        id: contentColumn
        x: avatar.x + avatar.width + Theme.paddingMedium
        y: Theme.paddingSmall
        width: peerTubeComment.width - x - Theme.horizontalPageMargin
        spacing: Theme.paddingSmall

        Row {
            width: parent.width
            spacing: Theme.paddingSmall

            AppLabel {
                width: Math.min(implicitWidth, parent.width - timeLabel.implicitWidth - parent.spacing)
                text: peerTubeComment.authorName
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                bold: true
                color: Theme.primaryColor
                useCustomFont: true
            }

            AppLabel {
                id: timeLabel
                // TimeManager.tick is read only so this re-evaluates when it is bumped
                text: { AppLib.TimeManager.tick; return peerTubeComment.createdAt ? PostMapper.formatTimeAgo(peerTubeComment.createdAt) : "" }
                font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                color: Theme.secondaryColor
            }
        }

        AppLabel {
            width: parent.width
            visible: peerTubeComment.isDeleted
            text: qsTr("Comment deleted")
            font.pixelSize: Theme.fontSizeSmall * sizeMultiplier
            font.italic: true
            color: Theme.secondaryColor
        }

        Item {
            width: parent.width
            height: commentText.implicitHeight
            visible: !peerTubeComment.isDeleted

            AppLabel {
                id: commentText
                anchors.fill: parent
                text: PostMapper.styleParagraphs(PostMapper.styleLinks(peerTubeComment.html,
                    palette.secondaryHighlightColor), Theme.paddingSmall)
                textFormat: Text.RichText
                useCustomFont: true
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall * sizeMultiplier
                color: Theme.primaryColor
                linkColor: palette.secondaryHighlightColor
            }

            MouseArea {
                anchors.fill: commentText
                onPressed: mouse.accepted = commentText.linkAt(mouse.x, mouse.y).length > 0
                onClicked: {
                    var link = commentText.linkAt(mouse.x, mouse.y)
                    if (link.length > 0)
                        peerTubeComment.linkClicked(link)
                }
            }
        }

        BackgroundItem {
            width: parent.width
            height: Theme.itemSizeExtraSmall
            visible: peerTubeComment.totalReplies > 0 && !peerTubeComment.repliesLoaded
            enabled: !peerTubeComment.repliesBusy
            onClicked: peerTubeComment.showReplies()

            AppLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: peerTubeComment.repliesBusy
                    ? qsTr("Loading…")
                    : qsTr("Show %n reply(ies)", "", peerTubeComment.totalReplies)
                font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                color: parent.highlighted ? palette.highlightColor : palette.secondaryHighlightColor
            }
        }
    }
}
