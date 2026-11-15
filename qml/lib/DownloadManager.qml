pragma Singleton
import QtQuick 2.0
import "PreferenceStorage.js" as PreferenceStorage

// App-wide download preferences
QtObject {
    id: downloadManager

    // Folder pictures from the image viewer are saved to. "" means the
    // default (~/Pictures/Meridon, decided natively by ImageSaver).
    property string imagePath: ""

    function selectImagePath(path) {
        downloadManager.imagePath = path
        PreferenceStorage.saveImageDownloadPath(path)
    }

    Component.onCompleted: {
        downloadManager.imagePath = PreferenceStorage.loadImageDownloadPath()
    }
}
