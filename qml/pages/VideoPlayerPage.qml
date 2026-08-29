import QtQuick 2.0
import QtMultimedia 5.6
import Sailfish.Silica 1.0
import "components"

FullscreenContentPage {
    id: videoPage
    // This page is actually not used at the moment
    // Slide up from the bottom
    navigationStyle: PageNavigation.Vertical

    property string playlistUrl: ""
    property string altText: ""

    property bool userPaused: false
    allowedOrientations: Orientation.All

    MediaPlayer {
        id: mediaPlayer
        source: videoPage.playlistUrl
        autoPlay: true

        onError: {
            console.warn("[VideoPlayer] playback error:", errorString)
        }

        onStatusChanged: {
            console.log("[VideoPlayer] status:", status)
        }
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        source: mediaPlayer
        fillMode: VideoOutput.PreserveAspectFit
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            overlay.active = !overlay.active
            if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                mediaPlayer.pause()
                userPaused = true
            } else {
                mediaPlayer.play()
                userPaused = false
            }
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: mediaPlayer.status === MediaPlayer.Loading
            || mediaPlayer.status === MediaPlayer.Buffering
        visible: running
    }

    ViewPlaceholder {
        enabled: mediaPlayer.error !== MediaPlayer.NoError
        text: qsTr("Couldn't play video")
        hintText: mediaPlayer.errorString
    }

    Item {
        id: overlay

        property bool active: true

        enabled: active
        anchors.fill: parent
        opacity: active ? 1.0 : 0.0
        Behavior on opacity { FadeAnimator {} }

        IconButton {
            y: Theme.paddingLarge
            anchors {
                right: parent.right
                rightMargin: Theme.horizontalPageMargin
            }
            icon.source: "image://theme/icon-m-dismiss"
            onClicked: pageStack.pop()
        }

        Rectangle {
            anchors.centerIn: parent
            width: Theme.iconSizeLarge * 1.4
            height: width
            radius: width / 2
            color: Theme.rgba("black", 0.55)
            visible: userPaused && mediaPlayer.status !== MediaPlayer.Loading

            Image {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: Theme.paddingSmall / 3
                source: "image://theme/icon-l-play?white"
                width: Theme.iconSizeLarge
                height: width
            }
        }

        AppLabel {
            anchors {
                bottom: parent.bottom
                bottomMargin: Theme.paddingLarge
                left: parent.left
                right: parent.right
                margins: Theme.horizontalPageMargin
            }
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: altText.length > 0
            color: Theme.rgba("white", 0.9)
            font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
            text: altText
        }
    }

    onStatusChanged: {
        // Stop playback (and free the decoder/network resources)
        if (status === PageStatus.Deactivating) {
            mediaPlayer.stop()
        }
    }
}
