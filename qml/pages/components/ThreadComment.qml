import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib
import "../../lib/PostMapper.js" as PostMapper

// One comment row of PeerTubePage and LemmyPage. Replies are indented by
// depth, up to a cap so deep threads still leave room for text.

Item {
    id: threadComment

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
    // Lemmy only: the whole thread is loaded, so loaded replies can be hidden again
    property bool canHide: false
    property bool showScore: false
    property int score: 0

    signal showReplies()
    signal hideReplies()
    signal linkClicked(string link)

    readonly property real indent: Math.min(depth, 3) * Theme.paddingLarge * 1.5

    width: parent ? parent.width : 0
    height: contentColumn.height + Theme.paddingLarge

    RoundedAvatar {
        id: avatar
        x: Theme.horizontalPageMargin + threadComment.indent
        y: Theme.paddingSmall
        size: Theme.iconSizeMedium
        source: threadComment.avatarUrl
        showBorder: false
    }

    Column {
        id: contentColumn
        x: avatar.x + avatar.width + Theme.paddingMedium
        y: Theme.paddingSmall
        width: threadComment.width - x - Theme.horizontalPageMargin
        spacing: Theme.paddingSmall

        Row {
            width: parent.width
            spacing: Theme.paddingSmall

            AppLabel {
                width: Math.min(implicitWidth, parent.width - timeLabel.implicitWidth
                                - (scoreLabel.visible ? scoreLabel.implicitWidth : 0) - 2 * parent.spacing)
                text: threadComment.authorName
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                bold: true
                color: Theme.primaryColor
                useCustomFont: true
            }

            AppLabel {
                id: timeLabel
                // TimeManager.tick is read only so this re-evaluates when it is bumped
                text: { AppLib.TimeManager.tick; return threadComment.createdAt ? PostMapper.formatTimeAgo(threadComment.createdAt) : "" }
                font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                color: Theme.secondaryColor
            }

            AppLabel {
                id: scoreLabel
                visible: threadComment.showScore
                text: qsTr("%n point(s)", "", threadComment.score)
                font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                color: Theme.secondaryColor
                opacity: Theme.opacityHigh
            }
        }

        AppLabel {
            width: parent.width
            visible: threadComment.isDeleted
            text: qsTr("Comment deleted")
            font.pixelSize: Theme.fontSizeSmall * sizeMultiplier
            font.italic: true
            color: Theme.secondaryColor
        }

        Item {
            width: parent.width
            height: commentText.implicitHeight
            visible: !threadComment.isDeleted

            AppLabel {
                id: commentText
                anchors.fill: parent
                text: PostMapper.styleParagraphs(PostMapper.styleLinks(threadComment.html,
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
                        threadComment.linkClicked(link)
                }
            }
        }

        BackgroundItem {
            width: parent.width
            height: Theme.itemSizeExtraSmall
            visible: threadComment.canHide && threadComment.totalReplies > 0 && threadComment.repliesLoaded
            onClicked: threadComment.hideReplies()

            AppLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Hide replies")
                font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                color: parent.highlighted ? palette.highlightColor : palette.secondaryHighlightColor
            }
        }

        BackgroundItem {
            width: parent.width
            height: Theme.itemSizeExtraSmall
            visible: threadComment.totalReplies > 0 && !threadComment.repliesLoaded
            enabled: !threadComment.repliesBusy
            onClicked: threadComment.showReplies()

            AppLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: threadComment.repliesBusy
                    ? qsTr("Loading…")
                    : qsTr("Show %n reply(ies)", "", threadComment.totalReplies)
                font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                color: parent.highlighted ? palette.highlightColor : palette.secondaryHighlightColor
            }
        }
    }
}
