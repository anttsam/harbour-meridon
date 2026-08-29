import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib

// Poll rendering + local vote-selection state

Column {
    id: postPoll

    property var poll: null

    // Chosen-but-not-yet-submitted option indices
    property var selectedIndices: []
    property bool submitting: false

    signal voteRequested(var choices)

    // Results (bars + percentages) replace the tappable option list on poll close
    readonly property bool showResults: poll && (poll.voted || poll.expired)

    visible: poll !== null
    width: parent.width
    spacing: Theme.paddingSmall

    Repeater {
        model: postPoll.poll ? postPoll.poll.options : []

        Item {
            id: optionItem
            width: postPoll.width
            height: Theme.itemSizeExtraSmall
            property int idx: index
            property real fraction: postPoll.poll && postPoll.poll.votesCount > 0
                ? modelData.votesCount / postPoll.poll.votesCount : 0
            property bool isOwnVote: postPoll.poll && postPoll.poll.ownVotes.indexOf(idx) !== -1
            property bool isSelected: postPoll.selectedIndices.indexOf(idx) !== -1

            Rectangle {
                visible: postPoll.showResults
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.primaryColor, 0.08)
            }

            Rectangle {
                visible: postPoll.showResults
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: parent.width * optionItem.fraction
                radius: Theme.paddingSmall
                color: optionItem.isOwnVote
                    ? Theme.rgba(AppLib.BackgroundManager.activeHighlightColor, 0.35)
                    : Theme.rgba(Theme.primaryColor, 0.18)
            }

            Rectangle {
                visible: !postPoll.showResults
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: "transparent"
                border.width: 1
                border.color: optionItem.isSelected ? AppLib.BackgroundManager.activeHighlightColor : Theme.rgba(Theme.primaryColor, 0.25)
            }

            AppLabel {
                anchors {
                    left: parent.left
                    right: percentLabel.left
                    leftMargin: Theme.paddingMedium
                    rightMargin: Theme.paddingSmall
                    verticalCenter: parent.verticalCenter
                }
                text: modelData.title
                truncationMode: TruncationMode.Fade
                font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                color: optionItem.isOwnVote ? palette.highlightColor : Theme.primaryColor
            }

            AppLabel {
                id: percentLabel
                visible: postPoll.showResults
                anchors {
                    right: parent.right
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                text: Math.round(optionItem.fraction * 100) + "%"
                font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                color: Theme.secondaryColor
            }

            MouseArea {
                anchors.fill: parent
                enabled: !postPoll.showResults && !postPoll.submitting
                onClicked: {
                    var next = postPoll.selectedIndices.slice()
                    var i = next.indexOf(optionItem.idx)
                    if (postPoll.poll.multiple) {
                        if (i === -1) next.push(optionItem.idx)
                        else next.splice(i, 1)
                    } else {
                        next = (i === -1) ? [optionItem.idx] : []
                    }
                    postPoll.selectedIndices = next
                }
            }
        }
    }

    Button {
        visible: !postPoll.showResults
        preferredWidth: Theme.buttonWidthSmall
        text: postPoll.submitting ? qsTr("Voting...") : qsTr("Vote")
        enabled: postPoll.selectedIndices.length > 0 && !postPoll.submitting
        onClicked: postPoll.voteRequested(postPoll.selectedIndices)
    }

    AppLabel {
        width: parent.width
        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
        color: Theme.secondaryColor
        text: {
            if (!postPoll.poll)
                return ""
            var votesText = qsTr("%1 votes").arg(postPoll.poll.votersCount)
            return postPoll.poll.expired
                ? (votesText + " · " + qsTr("Final results"))
                : votesText
        }
    }
}
