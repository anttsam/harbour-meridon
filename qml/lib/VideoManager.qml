pragma Singleton
import QtQuick 2.0
import "PreferenceStorage.js" as PreferenceStorage

// App-wide video/GIF playback preferences
QtObject {
    id: videoManager

    property bool autoplayGifs: false

    function selectAutoplayGifs(enabled) {
        videoManager.autoplayGifs = enabled
        PreferenceStorage.saveAutoplayGifs(enabled)
    }

    Component.onCompleted: {
        var saved = PreferenceStorage.loadAutoplayGifs()
        if (saved !== "")
            videoManager.autoplayGifs = saved === "1"
    }
}
