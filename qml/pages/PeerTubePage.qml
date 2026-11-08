import QtQuick 2.0
import QtMultimedia 5.6
import Sailfish.Silica 1.0
import "components"
import "../lib" as AppLib
import "../lib/PeerTube.js" as PeerTube
import "../lib/PostMapper.js" as PostMapper
import "../lib/LinkHandler.js" as LinkHandler

// A PeerTube video with its comments, read only. Mastodon can't carry either
// (see PeerTube.js), so everything here comes from the video's own host.
// Kept apart from PostDetailPage, which is built around Mastodon's /context.

AppPage {
    id: peerTubePage

    property string host: ""
    property string videoId: ""
    // The link the user followed, for the browser fallback
    property string pageUrl: ""
    // Callers that already fetched the video (to check it is one) pass it in
    property var video: null

    property string description: ""
    property string errorText: ""
    property bool busy: false

    property string sortMode: "newest" // newest | oldest
    property int threadsLoaded: 0
    property bool commentsLoading: false
    property bool commentsDone: false
    property string commentsError: ""
    // Drops responses from before a refresh or a change of sort order
    property int generation: 0

    readonly property int pageSize: 20
    readonly property string streamUrl: video ? PeerTube.pickStreamUrl(video) : ""
    readonly property bool commentsDisabled: video !== null
        && (video.commentsEnabled === false
            // 0 disabled, 1 enabled, 2 enabled but held for approval
            || (!!video.commentsPolicy && video.commentsPolicy.id === 0))
    readonly property string browserUrl: pageUrl.length > 0
        ? pageUrl : "https://" + host + "/w/" + videoId

    property bool playing: false

    ListModel {
        id: commentModel
    }

    function formatDuration(seconds) {
        var h = Math.floor(seconds / 3600)
        var m = Math.floor((seconds % 3600) / 60)
        var s = seconds % 60
        var mm = (h > 0 && m < 10 ? "0" : "") + m
        return (h > 0 ? h + ":" : "") + mm + ":" + (s < 10 ? "0" : "") + s
    }

    function openInBrowser() {
        playing = false
        pageStack.push(Qt.resolvedUrl("WebViewPage.qml"), { url: browserUrl })
    }

    function load() {
        generation++
        errorText = ""
        if (video) {
            loadDetails()
            return
        }
        busy = true
        var current = generation
        PeerTube.fetchVideo(host, videoId, function (json) {
            if (current !== generation)
                return
            busy = false
            video = json
            loadDetails()
        }, function (status, message) {
            if (current !== generation)
                return
            busy = false
            errorText = message
        })
    }

    function loadDetails() {
        description = video.description || ""
        PeerTube.fetchDescription(host, videoId, function (full) {
            if (full.length > 0)
                description = full
        })
        reloadComments()
    }

    function reloadComments() {
        generation++
        commentModel.clear()
        threadsLoaded = 0
        commentsDone = commentsDisabled
        commentsError = ""
        commentsLoading = false
        if (!commentsDisabled)
            loadComments()
    }

    function loadComments() {
        if (commentsLoading || commentsDone)
            return
        commentsLoading = true
        commentsError = ""
        var current = generation
        PeerTube.fetchThreads(host, videoId, threadsLoaded, pageSize,
            sortMode === "newest" ? "-createdAt" : "createdAt",
            function (json) {
                if (current !== generation)
                    return
                var threads = json.data || []
                for (var i = 0; i < threads.length; i++)
                    commentModel.append(PeerTube.mapComment(host, threads[i], 0))
                threadsLoaded += threads.length
                commentsDone = threads.length === 0 || threadsLoaded >= json.total
                commentsLoading = false
            },
            function (status, message) {
                if (current !== generation)
                    return
                commentsError = message
                commentsLoading = false
            })
    }

    function loadReplies(index) {
        var row = commentModel.get(index)
        var current = generation
        commentModel.setProperty(index, "repliesBusy", true)
        PeerTube.fetchThread(host, videoId, row.threadId, function (json) {
            if (current !== generation)
                return
            // rows moved if other threads were expanded meanwhile
            var at = -1
            for (var i = 0; i < commentModel.count; i++) {
                if (commentModel.get(i).commentId === row.commentId) {
                    at = i
                    break
                }
            }
            if (at < 0)
                return
            var replies = PeerTube.flattenReplies(host, json.children, 1)
            for (var r = 0; r < replies.length; r++)
                commentModel.insert(at + 1 + r, replies[r])
            commentModel.setProperty(at, "repliesBusy", false)
            commentModel.setProperty(at, "repliesLoaded", true)
        }, function () {
            if (current === generation)
                commentModel.setProperty(index, "repliesBusy", false)
        })
    }

    function applySort(mode) {
        if (sortMode === mode)
            return
        sortMode = mode
        reloadComments()
    }

    Component.onCompleted: load()

    // Stop playback when leaving the page or minimizing the app
    onStatusChanged: {
        if (status === PageStatus.Deactivating)
            playing = false
    }
    property bool appActive: Qt.application.active
    onAppActiveChanged: {
        if (!appActive)
            playing = false
    }

    MediaPlayer {
        id: mediaPlayer
        // Released (stopped, decoder freed) whenever playing is switched off
        source: peerTubePage.playing ? peerTubePage.streamUrl : ""
        autoPlay: true
        onError: console.warn("[PeerTubePage] playback error:", errorString)
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: commentModel
        cacheBuffer: 2000

        onAtYEndChanged: {
            if (atYEnd && count > 0)
                peerTubePage.loadComments()
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Open in browser")
                onClicked: peerTubePage.openInBrowser()
            }
            MenuItem {
                text: qsTr("Comments: Oldest first")
                visible: peerTubePage.sortMode !== "oldest"
                onClicked: peerTubePage.applySort("oldest")
            }
            MenuItem {
                text: qsTr("Comments: Newest first")
                visible: peerTubePage.sortMode !== "newest"
                onClicked: peerTubePage.applySort("newest")
            }
        }

        header: Column {
            width: listView.width

            PageHeader {
                title: peerTubePage.video && peerTubePage.video.channel
                    ? peerTubePage.video.channel.displayName : "PeerTube"
                description: peerTubePage.host
            }

            // Player: thumbnail until played, then the video itself
            Item {
                id: player
                width: parent.width
                height: width / Math.max(0.5, Math.min(peerTubePage.video && peerTubePage.video.aspectRatio
                                                       ? peerTubePage.video.aspectRatio : 1.78, 1.91))
                visible: peerTubePage.video !== null

                Rectangle {
                    anchors.fill: parent
                    color: "black"
                }

                Image {
                    anchors.fill: parent
                    visible: !peerTubePage.playing
                    source: peerTubePage.video
                        ? PeerTube.absoluteUrl(peerTubePage.host,
                              peerTubePage.video.previewPath || peerTubePage.video.thumbnailPath) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: width
                }

                VideoOutput {
                    anchors.fill: parent
                    visible: peerTubePage.playing
                    source: mediaPlayer
                    fillMode: VideoOutput.PreserveAspectFit
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    size: BusyIndicatorSize.Medium
                    running: peerTubePage.playing
                        && (mediaPlayer.status === MediaPlayer.Loading
                            || mediaPlayer.status === MediaPlayer.Buffering
                            || mediaPlayer.status === MediaPlayer.Stalled)
                    visible: running
                }

                // Play button, also shown while paused
                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.iconSizeLarge
                    height: width
                    radius: width / 2
                    color: Theme.rgba("black", 0.55)
                    visible: peerTubePage.streamUrl.length > 0
                        && (!peerTubePage.playing || mediaPlayer.playbackState === MediaPlayer.PausedState)

                    Image {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: Theme.paddingSmall / 4
                        source: "image://theme/icon-m-play?white"
                        width: Theme.iconSizeMedium
                        height: width
                    }
                }

                AppLabel {
                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                        margins: Theme.paddingSmall
                    }
                    visible: !peerTubePage.playing && !!peerTubePage.video && peerTubePage.video.duration > 0
                    text: peerTubePage.video ? peerTubePage.formatDuration(peerTubePage.video.duration) : ""
                    font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                    bold: true
                    color: "white"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: peerTubePage.streamUrl.length > 0
                    onClicked: {
                        if (!peerTubePage.playing)
                            peerTubePage.playing = true
                        else if (mediaPlayer.playbackState === MediaPlayer.PlayingState)
                            mediaPlayer.pause()
                        else
                            mediaPlayer.play()
                    }
                }

                // Position
                Rectangle {
                    anchors.bottom: parent.bottom
                    height: Theme.paddingSmall / 2
                    width: mediaPlayer.duration > 0 ? parent.width * mediaPlayer.position / mediaPlayer.duration : 0
                    color: palette.highlightColor
                    visible: peerTubePage.playing
                }

                IconButton {
                    anchors {
                        top: parent.top
                        right: parent.right
                    }
                    visible: peerTubePage.playing
                    icon.source: "image://theme/icon-m-dismiss"
                    onClicked: peerTubePage.playing = false
                }

                IconButton {
                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                    }
                    visible: peerTubePage.playing
                    icon.source: "image://theme/icon-m-enter-fullscreen"
                    onClicked: {
                        peerTubePage.playing = false
                        pageStack.push(Qt.resolvedUrl("VideoPlayerPage.qml"), {
                            playlistUrl: peerTubePage.streamUrl,
                            altText: peerTubePage.video.name
                        })
                    }
                }
            }

            Column {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium
                visible: peerTubePage.video !== null

                Item { width: 1; height: Theme.paddingSmall }

                AppLabel {
                    width: parent.width
                    text: peerTubePage.video ? peerTubePage.video.name : ""
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeMedium * sizeMultiplier
                    bold: true
                    color: Theme.primaryColor
                    useCustomFont: true
                }

                AppLabel {
                    width: parent.width
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                    color: Theme.secondaryColor
                    text: {
                        if (!peerTubePage.video)
                            return ""
                        var parts = [qsTr("%n view(s)", "", peerTubePage.video.views || 0)]
                        if (peerTubePage.video.publishedAt)
                            parts.push(new Date(peerTubePage.video.publishedAt)
                                       .toLocaleDateString(Qt.locale(), Locale.ShortFormat))
                        if (peerTubePage.video.likes)
                            parts.push(qsTr("%n like(s)", "", peerTubePage.video.likes))
                        return parts.join("  ·  ")
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.paddingMedium
                    visible: !!peerTubePage.video && !!peerTubePage.video.channel

                    RoundedAvatar {
                        id: channelAvatar
                        size: Theme.iconSizeMedium
                        source: peerTubePage.video ? PeerTube.avatarUrl(peerTubePage.host, peerTubePage.video.channel) : ""
                        showBorder: false
                    }

                    Column {
                        width: parent.width - channelAvatar.width - parent.spacing
                        anchors.verticalCenter: channelAvatar.verticalCenter

                        AppLabel {
                            width: parent.width
                            text: peerTubePage.video && peerTubePage.video.channel ? peerTubePage.video.channel.displayName : ""
                            truncationMode: TruncationMode.Fade
                            font.pixelSize: Theme.fontSizeSmall * sizeMultiplier
                            color: Theme.primaryColor
                        }
                        AppLabel {
                            width: parent.width
                            text: peerTubePage.video && peerTubePage.video.channel
                                ? "@" + peerTubePage.video.channel.name + "@" + peerTubePage.video.channel.host : ""
                            truncationMode: TruncationMode.Fade
                            font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                            color: Theme.secondaryColor
                        }
                    }
                }

                // Tap to expand
                AppLabel {
                    id: descriptionLabel
                    property bool expanded: false
                    width: parent.width
                    visible: peerTubePage.description.length > 0
                    text: peerTubePage.description
                    wrapMode: Text.Wrap
                    maximumLineCount: expanded ? 1000 : 4
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                    color: Theme.primaryColor
                    useCustomFont: true

                    MouseArea {
                        anchors.fill: parent
                        onClicked: descriptionLabel.expanded = !descriptionLabel.expanded
                    }
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: peerTubePage.video !== null && peerTubePage.streamUrl.length === 0
                    text: qsTr("Open in browser")
                    onClicked: peerTubePage.openInBrowser()
                }

                AppLabel {
                    width: parent.width
                    visible: peerTubePage.video !== null && peerTubePage.streamUrl.length === 0
                    text: peerTubePage.video && peerTubePage.video.isLive
                        ? qsTr("Live streams can't be played here")
                        : qsTr("This video can't be played here")
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                    color: Theme.secondaryColor
                }
            }

            SectionHeader {
                text: qsTr("Comments")
                visible: peerTubePage.video !== null
            }

            AppLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: peerTubePage.commentsDisabled
                text: qsTr("Comments are disabled")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall * sizeMultiplier
            }

            AppLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: peerTubePage.video !== null && !peerTubePage.commentsDisabled
                    && peerTubePage.commentsDone && commentModel.count === 0 && peerTubePage.commentsError.length === 0
                text: qsTr("No comments yet")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall * sizeMultiplier
            }
        }

        delegate: ThreadComment {
            depth: model.depth
            html: model.html
            isDeleted: model.isDeleted
            authorName: model.authorName
            authorHandle: model.authorHandle
            avatarUrl: model.avatarUrl
            createdAt: model.createdAt
            totalReplies: model.totalReplies
            repliesLoaded: model.repliesLoaded
            repliesBusy: model.repliesBusy
            onShowReplies: peerTubePage.loadReplies(index)
            onLinkClicked: LinkHandler.openLink(link, pageStack, {}, {})
        }

        footer: Item {
            width: listView.width
            height: peerTubePage.commentsLoading || peerTubePage.commentsError.length > 0
                ? Theme.itemSizeLarge : Theme.paddingLarge

            BusyIndicator {
                anchors.centerIn: parent
                running: peerTubePage.commentsLoading
                visible: running
                size: BusyIndicatorSize.Medium
            }

            Button {
                anchors.centerIn: parent
                visible: peerTubePage.commentsError.length > 0 && !peerTubePage.commentsLoading
                text: qsTr("Retry")
                onClicked: peerTubePage.loadComments()
            }
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: peerTubePage.errorText.length > 0
            text: qsTr("Couldn't load video")
            hintText: peerTubePage.errorText

            Button {
                anchors {
                    top: parent.bottom
                    topMargin: Theme.paddingLarge
                    horizontalCenter: parent.horizontalCenter
                }
                text: qsTr("Open in browser")
                onClicked: peerTubePage.openInBrowser()
            }
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: peerTubePage.busy
        visible: running
        size: BusyIndicatorSize.Large
    }
}
