import QtQuick 2.0
import Sailfish.Silica 1.0

// Image attachment grid.

Grid {
    id: imageGrid

    property var images: []

    visible: images.length > 0
    columns: images.length > 1 ? 2 : 1
    spacing: Theme.paddingSmall

    Repeater {
        model: imageGrid.images

        Image {
            id: postImage
            width: imageGrid.columns === 1
                ? imageGrid.width
                : (imageGrid.width - imageGrid.spacing) / 2
            height: width / modelData.aspectRatio
            fillMode: Image.PreserveAspectFit // never crops
            clip: true
            asynchronous: true
            source: modelData.thumbUrl

            onStatusChanged: {
                if (status === Image.Error)
                    console.warn("[PostImageGrid] post image decode failed:", modelData.thumbUrl)
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.overlayBackgroundColor
                visible: parent.status === Image.Loading
            }

            MouseArea {
                anchors.fill: parent
                enabled: parent.status === Image.Ready
                onClicked: pageStack.push(Qt.resolvedUrl("../ImageViewerPage.qml"), {
                    images: imageGrid.images,
                    startIndex: index
                })
            }
        }
    }
}
