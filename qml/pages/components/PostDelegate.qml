import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib
import "../../lib/SessionManager.js" as SessionManager
import "../../lib/PostMapper.js" as PostMapper
import "../../lib/LinkHandler.js" as LinkHandler

ListItem {
    id: postDelegate
    width: parent ? parent.width : Screen.width

    // when true, renders the "focus post" layout
    property bool isMainPost: false

    // focus post is not clickable (loop)
    property bool clickable: true

    property bool indented: false

    // used to hide the "Replying to @X"
    // hint is redundanta as there is a "line" showing this
    property bool hideReplyHint: false

    readonly property bool hasWarning: model.spoilerText.length > 0

    readonly property bool isOwnPost: model.authorId === SessionManager.getCurrentUserId()

    property bool cwRevealed: false

    // consider mainLoader.item
    contentHeight: (isMainPost
        ? (mainLoader.item ? mainLoader.item.y + mainLoader.item.height : 0)
        : compactLayout.y + compactLayout.height) + Theme.paddingMedium

    // no press-highlight when not clickable
    highlighted: clickable && down

    onClicked: {
        if (clickable) {
            pageStack.push(Qt.resolvedUrl("../PostDetailPage.qml"), {
                postUri: model.uri
            })
        }
    }

    // Wrapped in Component to imporove scrolling performance
    menu: Component {
        ContextMenu {
            MenuItem {
                visible: postDelegate.isOwnPost
                text: qsTr("Edit")
                onClicked: pageStack.push(Qt.resolvedUrl("../ComposePage.qml"), {
                    editingUri: model.uri
                })
            }

            MenuItem {
                visible: !postDelegate.isOwnPost
                text: qsTr("Mute thread")
                onClicked: postDelegate.muteThread()
            }

            MenuItem {
                text: qsTr("Copy to clipboard")
                onClicked: {
                    Clipboard.text = model.postText
                }
            }

            MenuItem {
                visible: model.permalink.length > 0
                text: qsTr("Copy link")
                onClicked: {
                    Clipboard.text = model.permalink
                }
            }

            MenuItem {
                visible: !postDelegate.isOwnPost
                text: qsTr("Hide post for me")
                onClicked: postDelegate.hidePostForMe()
            }

            MenuItem {
                visible: postDelegate.isOwnPost
                text: qsTr("Delete")
                onClicked: postDelegate.remorseAction(
                    qsTr("Deleting"),
                    function() { postDelegate.deletePost() },
                    2000
                )
            }
        }
    }

    // Optimistic favourite/unfavourite
    function toggleLike() {
        if (!model.uri)
            return

        var wasFavourited = model.favourited
        var previousCount = model.likeCount

        model.favourited = !wasFavourited
        model.likeCount = wasFavourited ? Math.max(0, previousCount - 1) : previousCount + 1

        var action = wasFavourited ? "unfavourite" : "favourite"
        SessionManager.authenticatedRequest("POST",
            "/api/v1/statuses/" + encodeURIComponent(model.uri) + "/" + action, {},
            function(response) {
                model.favourited = !!response.favourited
                model.likeCount = response.favourites_count || 0
            },
            function(status, message) {
                console.warn("[PostDelegate]", action, "failed:", status, message)
                model.favourited = wasFavourited
                model.likeCount = previousCount
            }
        )
    }

    function toggleRepost() {
        if (!model.uri)
            return

        var wasReblogged = model.reblogged
        var previousCount = model.repostCount

        model.reblogged = !wasReblogged
        model.repostCount = wasReblogged ? Math.max(0, previousCount - 1) : previousCount + 1

        var action = wasReblogged ? "unreblog" : "reblog"
        SessionManager.authenticatedRequest("POST",
            "/api/v1/statuses/" + encodeURIComponent(model.uri) + "/" + action, {},
            function(response) {
                var target = response.reblog || response
                model.reblogged = !!target.reblogged
                model.repostCount = target.reblogs_count || 0
            },
            function(status, message) {
                console.warn("[PostDelegate]", action, "failed:", status, message)
                model.reblogged = wasReblogged
                model.repostCount = previousCount
            }
        )
    }

    // Optimistic bookmark/unbookmark
    function toggleBookmark() {
        if (!model.uri)
            return

        var wasBookmarked = model.bookmarked
        model.bookmarked = !wasBookmarked

        var action = wasBookmarked ? "unbookmark" : "bookmark"
        SessionManager.authenticatedRequest("POST",
            "/api/v1/statuses/" + encodeURIComponent(model.uri) + "/" + action, {},
            function(response) {
                model.bookmarked = !!response.bookmarked
            },
            function(status, message) {
                console.warn("[PostDelegate]", action, "failed:", status, message)
                model.bookmarked = wasBookmarked
            }
        )
    }

    // Mastodon's "mute conversation" - stops future notifications about
    // this thread. Keyed by the status id alone.
    function muteThread() {
        if (!model.uri)
            return

        SessionManager.authenticatedRequest("POST",
            "/api/v1/statuses/" + encodeURIComponent(model.uri) + "/mute", {},
            function(response) {
                console.log("[PostDelegate] conversation muted:", model.uri)
            },
            function(status, message) {
                console.warn("[PostDelegate] mute conversation failed:", status, message)
            }
        )
    }

    // Local-only removal
    function hidePostForMe() {
        if (ListView.view && ListView.view.model && typeof ListView.view.model.remove === "function")
            ListView.view.model.remove(index)
    }

    // Own-post deletion
    function deletePost() {
        if (!model.uri)
            return

        var targetUri = model.uri
        SessionManager.authenticatedRequest("DELETE",
            "/api/v1/statuses/" + encodeURIComponent(targetUri), null,
            function(response) {
                var listModel = ListView.view && ListView.view.model
                if (!listModel || typeof listModel.remove !== "function")
                    return
                for (var i = 0; i < listModel.count; i++) {
                    if (listModel.get(i).uri === targetUri) {
                        listModel.remove(i)
                        break
                    }
                }
            },
            function(status, message) {
                console.warn("[PostDelegate] delete failed:", status, message)
            }
        )
    }

    // votePoll() lives here purely so it has direct access to "model" context
    function votePoll(pollItem, choices) {
        if (!pollItem || !pollItem.poll || pollItem.submitting || choices.length === 0)
            return

        pollItem.submitting = true
        SessionManager.authenticatedRequest("POST",
            "/api/v1/polls/" + encodeURIComponent(pollItem.poll.id) + "/votes",
            { choices: choices },
            function(response) {
                pollItem.submitting = false
                model.pollJson = JSON.stringify(PostMapper.mapPoll(response))
            },
            function(status, message) {
                pollItem.submitting = false
                console.warn("[PostDelegate] poll vote failed:", status, message)
            }
        )
    }

    Component {
        id: contentWarningComponent

        PostContentWarning {
            // parent here is whichever Loader instantiates this
            width: parent.width
            text: model.spoilerText
            revealed: postDelegate.cwRevealed
            onToggleRequested: postDelegate.cwRevealed = !postDelegate.cwRevealed
        }
    }

    Component {
        id: imageGridComponent

        PostImageGrid {
            images: model.embedImagesJson ? JSON.parse(model.embedImagesJson) : []
        }
    }

    Component {
        id: videoThumbComponent

        PostVideo {
            video: model.videoJson ? JSON.parse(model.videoJson) : null
            collapsedWidth: isMainPost
                ? (mainLoader.item ? mainLoader.item.width : 0)
                : compactContentColumn.width
            delegateRoot: postDelegate
        }
    }

    Component {
        id: pollComponent

        PostPoll {
            id: pollItem
            poll: model.pollJson ? JSON.parse(model.pollJson) : null
            onVoteRequested: postDelegate.votePoll(pollItem, choices)
        }
    }

    Component {
        id: statsRowComponent

        PostStatsRow {
            replyCount: model.replyCount
            repostCount: model.repostCount
            likeCount: model.likeCount
            favourited: model.favourited
            reblogged: model.reblogged
            bookmarked: model.bookmarked
            onReplyRequested: pageStack.push(Qt.resolvedUrl("../ComposePage.qml"), {
                replyToUri: model.uri,
                replyToAuthorName: model.displayName || model.handle,
                replyToAuthorEmojisJson: model.authorEmojisJson,
                replyToAuthorAvatar: model.avatarUrl,
                replyToText: model.postText
            })
            onRepostToggled: postDelegate.toggleRepost()
            onLikeToggled: postDelegate.toggleLike()
            onBookmarkToggled: postDelegate.toggleBookmark()
            onMoreRequested: postDelegate.openMenu()
        }
    }

    Component {
        id: avatarComponent

        RoundedAvatar {
            size: Theme.iconSizeMedium
            source: model.avatarUrl
        }
    }

    Component {
        id: externalCardComponent

        PostLinkCard {
            link: model.externalJson ? JSON.parse(model.externalJson) : null
        }
    }

    Component {
        id: quoteCardComponent

        PostQuoteCard {
            quote: model.quoteJson ? JSON.parse(model.quoteJson) : null
        }
    }

    // Vertical thread-chain connector flag, running through the avatar's top down to next avatar top
    property bool showThreadLine: false

    property bool isLastThreadItem: ListView.view
        ? (index === ListView.view.count - 1) : true

    Rectangle {
        // thread-chain line
        visible: showThreadLine && !isMainPost
            && !isLastThreadItem && model.hasDisplayedContinuation === true
        width: 2
        height: parent.height
        x: Theme.horizontalPageMargin + Theme.iconSizeMedium / 2 - width / 2
        y: compactLayout.y + Theme.paddingSmall
        color: Theme.rgba(Theme.primaryColor, 0.25)
        z: -1
    }

    // "Boosted by X"
    Row {
        id: repostHintRow
        visible: !isMainPost && model.isRepost === true
        x: Theme.horizontalPageMargin
        y: Theme.paddingSmall
        width: parent.width - 2 * Theme.horizontalPageMargin
        height: visible ? implicitHeight : 0
        spacing: Theme.paddingSmall

        Image {
            source: "image://theme/icon-s-retweet"
            width: Theme.iconSizeExtraSmall
            height: width
            anchors.verticalCenter: parent.verticalCenter
            opacity: 0.7
        }

        AppLabel {
            text: qsTr("Boosted by %1").arg(AppLib.EmojiManager.render(model.repostByName || model.repostByHandle, model.repostByEmojisJson, (Theme.fontSizeExtraSmall) * sizeMultiplier))
            textFormat: Text.StyledText
            useCustomFont: true
            font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
            color: Theme.secondaryColor
            truncationMode: TruncationMode.Fade
            width: parent.width - Theme.iconSizeExtraSmall - parent.spacing
        }
    }

    // "Replying to X"
    Row {
        id: replyHintRow
        visible: !hideReplyHint && model.isReply === true && model.replyToHandle.length > 0
        x: Theme.horizontalPageMargin
        y: repostHintRow.visible
            ? (repostHintRow.y + repostHintRow.height + Theme.paddingSmall)
            : Theme.paddingSmall
        width: parent.width - 2 * Theme.horizontalPageMargin
        height: visible ? implicitHeight : 0
        spacing: Theme.paddingSmall

        Image {
            source: "image://theme/icon-s-chat"
            width: Theme.iconSizeExtraSmall
            height: width
            anchors.verticalCenter: parent.verticalCenter
            opacity: 0.7
        }

        AppLabel {
            // replyToName is only ever populated for a self-reply, mastodon don't return the name
            text: qsTr("Replying to %1").arg(model.replyToName.length > 0
                ? AppLib.EmojiManager.render(model.replyToName, model.authorEmojisJson, (Theme.fontSizeExtraSmall) * sizeMultiplier)
                : "@" + model.replyToHandle)
            useCustomFont: true
            font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
            color: Theme.secondaryColor
            truncationMode: TruncationMode.Fade
            width: parent.width - Theme.iconSizeExtraSmall - parent.spacing
        }
    }

    // ---- Compact layout: used in feeds and reply lists.
    Row {
        id: compactLayout
        visible: !isMainPost
        x: Theme.horizontalPageMargin
        y: replyHintRow.visible
            ? (replyHintRow.y + replyHintRow.height + Theme.paddingSmall)
            : (repostHintRow.visible
                ? (repostHintRow.y + repostHintRow.height + Theme.paddingSmall)
                : Theme.paddingMedium)
        width: parent.width - 2 * Theme.horizontalPageMargin
        spacing: Theme.paddingMedium * 0.8

        Item {
            id: avatarTapArea
            width: compactAvatar.width
            height: compactAvatar.height

            Loader {
                id: compactAvatar
                anchors.top: parent.top
                anchors.topMargin: Theme.paddingSmall * 0.95
                sourceComponent: !isMainPost ? avatarComponent : undefined
            }

            MouseArea {
                anchors.fill: parent
                onClicked: pageStack.push(Qt.resolvedUrl("../UserProfilePage.qml"), {
                    did: model.authorId
                })
            }
        }

        Column {
            id: compactContentColumn
            width: compactLayout.width - compactAvatar.width - compactLayout.spacing
            spacing: Theme.paddingSmall //changed this

            Item {
                width: parent.width
                height: compactNameHandleColumn.height
                Row {
                    id: compactNameHandleColumn
                    width: parent.width
                    spacing: Theme.paddingSmall

                    AppLabel {
                        id: displayNameLabel
                        text: AppLib.EmojiManager.render(model.displayName || model.handle, model.authorEmojisJson, (Theme.fontSizeSmall) * sizeMultiplier)
                        textFormat: Text.StyledText
                        useCustomFont: true
                        font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                        bold: true
                        truncationMode: TruncationMode.Fade
                        width: Math.min(contentWidth, parent.width -  2* parent.spacing - agoLabel.width)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    AppLabel {
                        text: "@" + model.handle +" ·"
                        color: Theme.secondaryColor
                        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                        truncationMode: TruncationMode.Fade
                        width: Math.min(contentWidth, parent.width -  2* parent.spacing - displayNameLabel.width - agoLabel.width)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    AppLabel {
                        id: agoLabel
                        text: model.timeAgo
                        color: Theme.secondaryColor
                        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                        truncationMode: TruncationMode.Fade
                        //width: parent.width //- parent.spacing - displayNameLabel.width
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: 0.6
                    }
                }
            }


            Loader {
                width: parent.width
                active: postDelegate.hasWarning
                sourceComponent: active ? contentWarningComponent : undefined
            }

            Item {
                width: parent.width
                height: postTextLabel.implicitHeight
                // only visible if post has text - don't show empty line in a pure image post for example
                visible: model.postText.length > 0 && (!postDelegate.hasWarning || postDelegate.cwRevealed)

                AppLabel {
                    id: postTextLabel
                    anchors.fill: parent
                    text: PostMapper.styleParagraphs(PostMapper.styleLinks(
                        AppLib.EmojiManager.render(model.postText, model.postEmojisJson, (Theme.fontSizeSmall) * sizeMultiplier),
                        palette.secondaryHighlightColor), Theme.paddingSmall)
                    textFormat: Text.RichText
                    useCustomFont: true
                    wrapMode: Text.Wrap
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                    color: Theme.primaryColor
                    linkColor: palette.secondaryHighlightColor
                }

                MouseArea {
                    anchors.fill: postTextLabel
                    onPressed: mouse.accepted = postTextLabel.linkAt(mouse.x, mouse.y).length > 0
                    onClicked: {
                        var link = postTextLabel.linkAt(mouse.x, mouse.y)
                        if (link.length === 0)
                            return
                        var mentions = model.mentionsJson ? JSON.parse(model.mentionsJson) : {}
                        var tags = model.tagsJson ? JSON.parse(model.tagsJson) : {}
                        LinkHandler.openLink(link, pageStack, mentions, tags)
                    }
                }
            }

            //Load the correct components

            Loader {
                width: parent.width
                active: !isMainPost && model.pollJson && model.pollJson.length > 0 && (!postDelegate.hasWarning || postDelegate.cwRevealed)
                sourceComponent: active ? pollComponent : undefined
                visible: active
            }
            Loader {
                width: parent.width
                active: !isMainPost && model.embedImagesJson && model.embedImagesJson !== "[]" && (!postDelegate.hasWarning || postDelegate.cwRevealed)
                sourceComponent: active ? imageGridComponent : undefined
                visible: active
            }
            Loader {
                // No width binding here - need to expand
                active: !isMainPost && model.videoJson && model.videoJson.length > 0 && (!postDelegate.hasWarning || postDelegate.cwRevealed)
                sourceComponent: active ? videoThumbComponent : undefined
                visible: active
            }
            Loader {
                width: parent.width
                active: !isMainPost && model.externalJson && model.externalJson.length > 0 && (!postDelegate.hasWarning || postDelegate.cwRevealed)
                sourceComponent: active ? externalCardComponent : undefined
                visible: active
            }
            Loader {
                width: parent.width
                active: !isMainPost && model.quoteJson && model.quoteJson.length > 0 && (!postDelegate.hasWarning || postDelegate.cwRevealed)
                sourceComponent: active ? quoteCardComponent : undefined
                visible: active
            }
            Loader { width: parent.width; sourceComponent: !isMainPost ? statsRowComponent : undefined }
        }
    }


    // ---- Main post layout

    Loader {
        id: mainLoader
        active: isMainPost
        sourceComponent: active ? mainLayoutComponent : undefined
    }

    Component {
        id: mainLayoutComponent

    Column {
        id: mainLayout
        x: Theme.horizontalPageMargin
        y: Theme.paddingMedium
        width: postDelegate.width - 2 * Theme.horizontalPageMargin
        spacing: Theme.paddingMedium

        Item {
            width: parent.width
            height: mainAuthorRow.height

            Row {
                id: mainAuthorRow
                width: parent.width
                spacing: Theme.horizontalPageMargin

                Loader {
                    sourceComponent: isMainPost ? avatarComponent : undefined
                    anchors.top: parent.top
                    anchors.topMargin: Theme.paddingSmall * 1.1
                    scale: 1.2
                }

                Column {
                    id: nameHandleColumn
                    width: parent.width - Theme.iconSizeMedium - parent.spacing
                    //anchors.top: parent.top
                    AppLabel {
                        text: AppLib.EmojiManager.render(model.displayName || model.handle, model.authorEmojisJson, (Theme.fontSizeSmall) * sizeMultiplier)
                        textFormat: Text.StyledText
                        useCustomFont: true
                        font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                        bold: true
                        truncationMode: TruncationMode.Fade
                        width: parent.width - Theme.paddingLarge
                        //verticalAlignment: Text.AlignTop
                    }
                    Row {
                        id: handleRow
                        width: parent.width
                        spacing: Theme.paddingSmall
                        AppLabel {
                            id: mainHandleText
                            text: "@" + model.handle + " ·"
                            color: Theme.secondaryColor
                            font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                            truncationMode: TruncationMode.Fade
                            width: Math.min(contentWidth, parent.width -  2* parent.spacing - mainAgoLabel.width)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        AppLabel {
                            id: mainAgoLabel
                            text: model.timeAgo
                            color: Theme.secondaryColor
                            font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                            truncationMode: TruncationMode.Fade
                            anchors.verticalCenter: mainHandleText.verticalCenter
                            opacity: 0.6
                        }
                    }
                }

            }
            MouseArea {
                anchors.fill: mainAuthorRow
                onClicked: pageStack.push(Qt.resolvedUrl("../UserProfilePage.qml"), {
                    did: model.authorId
                })
            }
        }

        Loader {
            width: parent.width
            active: postDelegate.hasWarning
            sourceComponent: active ? contentWarningComponent : undefined
        }

        Item {
            width: parent.width
            height: mainPostTextLabel.implicitHeight
            visible: model.postText.length > 0 && (!postDelegate.hasWarning || postDelegate.cwRevealed)

            AppLabel {
                id: mainPostTextLabel
                anchors.fill: parent
                text: PostMapper.styleParagraphs(PostMapper.styleLinks(
                    AppLib.EmojiManager.render(model.postText, model.postEmojisJson, (Theme.fontSizeMedium) * sizeMultiplier),
                    palette.secondaryHighlightColor), Theme.paddingSmall)
                textFormat: Text.RichText
                useCustomFont: true
                wrapMode: Text.Wrap
                font.pixelSize: (Theme.fontSizeMedium) * sizeMultiplier // slightly larger for the focus post
                color: Theme.primaryColor
                linkColor: palette.secondaryHighlightColor
            }

            MouseArea {
                anchors.fill: mainPostTextLabel
                onPressed: mouse.accepted = mainPostTextLabel.linkAt(mouse.x, mouse.y).length > 0
                onClicked: {
                    var link = mainPostTextLabel.linkAt(mouse.x, mouse.y)
                    if (link.length === 0)
                        return
                    var mentions = model.mentionsJson ? JSON.parse(model.mentionsJson) : {}
                    var tags = model.tagsJson ? JSON.parse(model.tagsJson) : {}
                    LinkHandler.openLink(link, pageStack, mentions, tags)
                }
            }
        }

        Loader {
            width: parent.width
            active: isMainPost && model.pollJson && model.pollJson.length > 0 && (!postDelegate.hasWarning || postDelegate.cwRevealed)
            sourceComponent: active ? pollComponent : undefined
            visible: active
        }
        Loader {
            width: parent.width
            active: isMainPost && model.embedImagesJson && model.embedImagesJson !== "[]" && (!postDelegate.hasWarning || postDelegate.cwRevealed)
            sourceComponent: active ? imageGridComponent : undefined
            visible: active
        }
        Loader {
            // No explicit width
            active: isMainPost && model.videoJson && model.videoJson.length > 0 && (!postDelegate.hasWarning || postDelegate.cwRevealed)
            sourceComponent: active ? videoThumbComponent : undefined
            visible: active
        }
        Loader {
            width: parent.width
            active: isMainPost && model.externalJson && model.externalJson.length > 0 && (!postDelegate.hasWarning || postDelegate.cwRevealed)
            sourceComponent: active ? externalCardComponent : undefined
            visible: active
        }
        Loader {
            width: parent.width
            active: isMainPost && model.quoteJson && model.quoteJson.length > 0 && (!postDelegate.hasWarning || postDelegate.cwRevealed)
            sourceComponent: active ? quoteCardComponent : undefined
            visible: active
        }

        Loader { width: parent.width; sourceComponent: isMainPost ? statsRowComponent : undefined }
    }
    }
}
