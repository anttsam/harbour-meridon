import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"

FullscreenContentPage {
    id: viewerPage

    navigationStyle: PageNavigation.Vertical
    allowedOrientations: Orientation.All

    // Array of {thumbUrl, fullsizeUrl, alt, aspectRatio}
    property var images: []
    property int startIndex: 0

    property real minScale: 1.0
    property real maxScale: 4.0

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

        AppLabel {
            anchors {
                bottom: parent.bottom
                bottomMargin: Theme.paddingLarge
                horizontalCenter: parent.horizontalCenter
            }
            width: parent.width - 2 * Theme.horizontalPageMargin
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: text.length > 0
            useCustomFont: true
            color: Theme.secondaryColor
            font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
            text: (slideshow.currentIndex >= 0 && slideshow.currentIndex < viewerPage.images.length)
                ? (viewerPage.images[slideshow.currentIndex].alt || "") : ""
        }
    }
}
