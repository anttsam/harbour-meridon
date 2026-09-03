import QtQuick 2.0
import Sailfish.Silica 1.0

// Image attachment grid.

Grid {
    id: imageGrid

    property var images: []

    // limit the height of extreme heigh image
    readonly property real maxCellAspectRatio: 1.5

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
            height: Math.min(width / modelData.aspectRatio, width * imageGrid.maxCellAspectRatio)
            fillMode: Image.PreserveAspectCrop
            clip: true
            asynchronous: true
            // Caps decode to grid size - fullsize viewing in ImageViewerPage
            sourceSize.width: width
            sourceSize.height: height
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
