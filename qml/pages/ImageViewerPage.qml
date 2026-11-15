import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.meridon.Native 1.0
import "components"
import "../lib" as AppLib

FullscreenContentPage {
    id: viewerPage

    navigationStyle: PageNavigation.Vertical
    allowedOrientations: Orientation.All

    // Array of {thumbUrl, fullsizeUrl, alt, aspectRatio}
    property var images: []
    property int startIndex: 0

    property real minScale: 1.0
    property real maxScale: 4.0

    readonly property var currentImage: (slideshow.currentIndex >= 0 && slideshow.currentIndex < images.length)
                                        ? images[slideshow.currentIndex] : null
    readonly property string currentAlt: (currentImage && currentImage.alt) ? String(currentImage.alt).trim() : ""

    // ALT text is hidden until the "ALT" button is tapped
    property bool altShown: false
    property bool saving: false

    Connections {
        target: slideshow
        onCurrentIndexChanged: viewerPage.altShown = false
    }

    ImageSaver {
        id: imageSaver

        onSaved: {
            viewerPage.saving = false
            Notices.show(qsTr("Saved as %1").arg(fileName), Notice.Short, Notice.Center)
        }
        onFailed: {
            viewerPage.saving = false
            Notices.show(qsTr("Couldn't save the picture"), Notice.Short, Notice.Center)
        }
    }

    SlideshowView {
        id: slideshow
        anchors.fill: parent
        model: viewerPage.images
        currentIndex: viewerPage.startIndex

        delegate: Item {
            id: slideItem
            width: PathView.view.width
            height: PathView.view.height

            SilicaFlickable {
                id: flick
                anchors.fill: parent
                contentWidth: imageContainer.width
                contentHeight: imageContainer.height
                clip: true

                BusyIndicator {
                    anchors.centerIn: parent
                    running: image.status === Image.Loading
                    visible: running
                    size: BusyIndicatorSize.Large
                }

                Item {
                    id: imageContainer
                    width: Math.max(image.width * image.scale, flick.width)
                    height: Math.max(image.height * image.scale, flick.height)

                    Image {
                        id: image

                        property real prevScale: 1.0

                        anchors.centerIn: parent
                        width: flick.width
                        height: flick.height
                        source: modelData.fullsizeUrl
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit

                        // Keep the Flickable's pan position sane
                        onScaleChanged: {
                            if ((width * scale) > flick.width) {
                                var xoff = (flick.width / 2 + flick.contentX) * scale / prevScale
                                flick.contentX = xoff - flick.width / 2
                            }
                            if ((height * scale) > flick.height) {
                                var yoff = (flick.height / 2 + flick.contentY) * scale / prevScale
                                flick.contentY = yoff - flick.height / 2
                            }
                            prevScale = scale
                        }
                    }
                }

                PinchArea {
                    anchors.fill: parent
                    pinch.target: image
                    pinch.minimumScale: viewerPage.minScale
                    pinch.maximumScale: viewerPage.maxScale

                    onPinchFinished: {
                        flick.returnToBounds()
                        if (image.scale < viewerPage.minScale)
                            image.scale = viewerPage.minScale
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: overlay.active = !overlay.active
                        onDoubleClicked: {
                            image.scale = (image.scale > viewerPage.minScale)
                                ? viewerPage.minScale
                                : viewerPage.maxScale
                        }
                    }
                }
            }
        }
    }

    Item {
        id: overlay

        property bool active: true

        enabled: active
        anchors.fill: parent
        opacity: active ? 1.0 : 0.0
        Behavior on opacity { FadeAnimator {} }

        IconButton {
            id: closeButton
            y: Theme.paddingLarge
            anchors {
                right: parent.right
                rightMargin: Theme.horizontalPageMargin
            }
            icon.source: "image://theme/icon-m-dismiss"
            onClicked: pageStack.pop()
        }

        // "2 / 4" position indicator - when there are multiple images
        AppLabel {
            anchors {
                verticalCenter: closeButton.verticalCenter
                horizontalCenter: parent.horizontalCenter
            }
            visible: viewerPage.images.length > 1
            useCustomFont: true
            text: (slideshow.currentIndex + 1) + " / " + viewerPage.images.length
            color: Theme.secondaryColor
            font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
        }

        IconButton {
            id: downloadButton
            anchors {
                right: parent.right
                rightMargin: Theme.horizontalPageMargin
                bottom: parent.bottom
                bottomMargin: Theme.paddingLarge
            }
            icon.source: "image://theme/icon-m-cloud-download"
            enabled: !viewerPage.saving && !!viewerPage.currentImage && !!viewerPage.currentImage.fullsizeUrl
            opacity: enabled ? 1.0 : Theme.opacityLow
            onClicked: {
                viewerPage.saving = true
                imageSaver.save(String(viewerPage.currentImage.fullsizeUrl),
                                AppLib.DownloadManager.imagePath)
            }
        }

        // "ALT" badge, like in the official Mastodon app - only for pictures
        // that have a description
        Item {
            id: altButton
            visible: viewerPage.currentAlt.length > 0
            anchors {
                left: parent.left
                leftMargin: Theme.horizontalPageMargin - Theme.paddingMedium
                bottom: parent.bottom
                bottomMargin: Theme.paddingLarge
            }
            width: altBadge.width + 2 * Theme.paddingMedium
            height: Theme.itemSizeSmall

            Rectangle {
                id: altBadge
                anchors.centerIn: parent
                width: altBadgeLabel.width + 2 * Theme.paddingMedium
                height: altBadgeLabel.height + Theme.paddingMedium
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.overlayBackgroundColor, 0.8)
                border.width: 1
                border.color: viewerPage.altShown ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0.4)

                AppLabel {
                    id: altBadgeLabel
                    //anchors.centerIn: parent
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: Theme.paddingSmall/2
                    useCustomFont: true
                    bold: true
                    text: qsTr("ALT")
                    color: viewerPage.altShown ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: viewerPage.altShown = !viewerPage.altShown
            }
        }

        // The description on a translucent panel, so it stays readable over
        // bright pictures. Long descriptions scroll.
        Rectangle {
            id: altPanel
            visible: viewerPage.altShown && viewerPage.currentAlt.length > 0
            anchors {
                left: parent.left
                right: parent.right
                margins: Theme.horizontalPageMargin
                bottom: altButton.top
            }
            height: Math.min(altFlickable.contentHeight + 2 * Theme.paddingMedium,
                             viewerPage.height * 0.4)
            radius: Theme.paddingSmall
            color: Theme.rgba(Theme.overlayBackgroundColor, 0.8)

            SilicaFlickable {
                id: altFlickable
                anchors {
                    fill: parent
                    margins: Theme.paddingMedium
                }
                clip: true
                contentHeight: altLabel.height

                AppLabel {
                    id: altLabel
                    width: parent.width
                    wrapMode: Text.Wrap
                    useCustomFont: true
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall * sizeMultiplier
                    text: viewerPage.currentAlt
                }

                VerticalScrollDecorator {}
            }
        }
    }
}
