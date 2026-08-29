import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib

// Drop-in Page that tints itself with the user's chosen background
// opacity (Settings page), instead of showing the Ambience wallpaper
// through at full strength.

Page {
    backgroundColor: AppLib.BackgroundManager.backgroundColor

    palette.highlightColor: AppLib.BackgroundManager.activeHighlightColor

    // didn't like the generated one..
    palette.highlightBackgroundColor: AppLib.BackgroundManager.activeHighlightBackgroundColor

    NoiseOverlay {
        anchors.fill: parent
        strength: 0.04
    }

}
