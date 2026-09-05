import QtQuick 2.0
import QtMultimedia 5.6
import Sailfish.Silica 1.0
import "../../lib/VideoExpansionTracker.js" as VideoExpansionTracker
import "../../lib" as AppLib

// Two-stage tap-to-play/expand video player

Item {
    id: postVideo

    property var video: null
    property real collapsedWidth: 0

    // The delegate root (postDelegate in PostDelegate.qml)
    property Item delegateRoot: null

    // Two-stage tap, the first tap starts muted, inline playback
    property bool playing: false
    // a second tap - only expands to full-width and unmutes.
    property bool expanded: false

    // True once the player has actually reached PlayingState (not just "loading"/"buffering")
    // drives hiding the play button/GIF badge only atm
    property bool videoPlaying: false

    // Stop playback whenever the app is minimized/backgrounded.
    property bool appActive: Qt.application.active
    onAppActiveChanged: {
        if (!appActive) {
            postVideo.expanded = false
            postVideo.playing = false
        } else {
            postVideo.updateGifAutoplay()
        }
    }

    // Autoplay/pause a GIF as it scrolls in and out of the viewport - unlike
    // a real video (deliberately tap-to-play, since starting a decoder for
    // every visible post would be costly), a GIF attachment is meant to
    // play immediately like an animated image. Still gated on visibility
    // rather than "always on" so scrolling past several GIFs in a row
    // doesn't leave every one of them decoding in the background at once.
    // Computed imperatively (not a declarative binding) to match
    // ScrollDirectionTracker.qml's own proven pattern for reacting to
    // contentY on this Qt version.
    function updateGifAutoplay() {
        if (!AppLib.VideoManager.autoplayGifs
            || !postVideo.video || !postVideo.video.isGif || postVideo.expanded)
            return

        var view = postVideo.ListView.view
        if (!view) {
            postVideo.playing = true
            return
        }

        var pos = postVideo.mapToItem(view.contentItem, 0, 0)
        var itemTop = pos.y
        var itemBottom = itemTop + postVideo.height
        var viewTop = view.contentY
        var viewBottom = viewTop + view.height
        var isVisible = itemBottom > viewTop && itemTop < viewBottom

        if (isVisible && !postVideo.playing)
            postVideo.playing = true
        else if (!isVisible && postVideo.playing)
            postVideo.playing = false
    }
    Component.onCompleted: updateGifAutoplay()

    Connections {
        target: postVideo.ListView.view
        ignoreUnknownSignals: true
        onContentYChanged: postVideo.updateGifAutoplay()
    }

    Connections {
        target: AppLib.VideoManager
        onAutoplayGifsChanged: postVideo.updateGifAutoplay()
    }

    property real expandOffsetX: 0

    // calculate new position on change
    onExpandedChanged: {
        if (expanded) {
            expandOffsetX = mapToItem(postVideo.delegateRoot, 0, 0).x

            var view = postVideo.ListView.view
            if (view) {
                var topY = mapToItem(view.contentItem, 0, 0).y
                var targetHeight = video ? targetWidth / video.aspectRatio : 0
                var videoCenterY = topY + targetHeight / 2
                var targetContentY = videoCenterY - view.height / 2

                targetContentY = Math.max(0, Math.min(targetContentY,
                    Math.max(0, view.contentHeight - view.height)))

                centerVideoAnimation.target = view
                centerVideoAnimation.to = targetContentY
                centerVideoAnimation.restart()
            }

            VideoExpansionTracker.videoExpanded()  // hide the tabbar
        } else {
            VideoExpansionTracker.videoCollapsed() // show the tabbar
        }
    }

    // Safety net for VideoExpansionTracker's counter, avoid hiding tabbar forever
    Component.onDestruction: {
        if (expanded)
            VideoExpansionTracker.videoCollapsed()
    }

    // Animates the list's contentY move to video center and expansion
    NumberAnimation {
        id: centerVideoAnimation
        property: "contentY"
        duration: 200
        easing.type: Easing.InOutQuad
    }
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

    // targetWidth computed
    readonly property real targetWidth: expanded ? Screen.width : collapsedWidth

    visible: video !== null
    width: targetWidth
    x: expanded ? -expandOffsetX : 0
    height: video ? targetWidth / video.aspectRatio : 0

    // First frame of video shown also during buffering
    Image {
        id: videoThumbImage
        anchors.fill: parent
        visible: parent.video && !postVideo.expanded && parent.video.thumbnailUrl.length > 0
        source: parent.video ? parent.video.thumbnailUrl : ""
        fillMode: Image.PreserveAspectCrop
        clip: true
        asynchronous: true
        sourceSize.width: width
        sourceSize.height: height
    }

    Rectangle {
        anchors.fill: parent
        visible: !videoThumbImage.visible && !postVideo.expanded // no thumbnail available
        color: Theme.rgba(Theme.primaryColor, 0.15)
    }

    // Player exists only while playing (first tap onward) - kept out of every video post's delegate
    Loader {
        anchors.fill: parent
        active: postVideo.playing
        sourceComponent: Component {
            Item {
                MediaPlayer {
                    id: mediaPlayer
                    source: postVideo.video ? postVideo.video.playlistUrl : ""
                    autoPlay: true
                    // Unmuted only when expanded, one can argue if this is cool
                    muted: !postVideo.expanded
                    onError: console.warn("[PostVideo] video playback error:", errorString)
                    onPlaybackStateChanged: {
                        if (playbackState === MediaPlayer.PlayingState)
                            postVideo.videoPlaying = true
                    }
                    // manual start as autoplay failes sometimes
                    Component.onCompleted: play()
                }
                VideoOutput {
                    anchors.fill: parent
                    source: mediaPlayer
                    fillMode: VideoOutput.PreserveAspectFit
                }
                BusyIndicator {
                    anchors.centerIn: parent
                    size: BusyIndicatorSize.Medium
                    running: mediaPlayer.status === MediaPlayer.Loading
                        || mediaPlayer.status === MediaPlayer.Buffering
                    visible: running
                }
                // Release the decoder/network resources
                Component.onDestruction: {
                    mediaPlayer.stop()
                    postVideo.videoPlaying = false
                }
            }
        }
    }

    // Play button overlay - hidden once actually playing
    Rectangle {
        anchors.centerIn: parent
        visible: !postVideo.videoPlaying && !(parent.video && parent.video.isGif)
        width: Theme.iconSizeLarge
        height: width
        radius: width / 2
        color: Theme.rgba("black", 0.55)

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
        visible: !postVideo.videoPlaying && parent.video && parent.video.isGif
        text: "GIF"
        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
        bold: true
        color: "white"
    }

    // Two-stage: first tap starts muted playback, second tap expands and third unepands and stops playback
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!postVideo.playing)
                postVideo.playing = true
            else {
                postVideo.expanded = !postVideo.expanded
                if (!postVideo.expanded) {
                    postVideo.playing = false
                    // Resume ambient GIF autoplay if still visible - unlike
                    // the explicit stop button below, collapsing isn't
                    // meant to stop playback for good.
                    postVideo.updateGifAutoplay()
                }
            }
        }
    }

    // Discoverable way to stop - visible any time there's something to stop
    IconButton {
        anchors {
            top: parent.top
            right: parent.right
            margins: Theme.paddingSmall
        }
        visible: postVideo.playing
        icon.source: "image://theme/icon-m-dismiss"
        onClicked: {
            postVideo.expanded = false
            postVideo.playing = false
        }
    }
}
