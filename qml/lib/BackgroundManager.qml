pragma Singleton
import QtQuick 2.0
import Sailfish.Silica 1.0
import "PreferenceStorage.js" as PreferenceStorage

// App-wide page background tint, applied via AppPage.qml

QtObject {
    id: backgroundManager

    readonly property real opacityMin: 0.0
    readonly property real opacityMax: 1.0
    property real opacity: 0.5

    readonly property string colorKeyPrimary: "primary"
    readonly property string colorKeySecondary: "secondary"
    readonly property string colorKeyMastodon: "mastodon"
    property string colorKey: colorKeyPrimary

    readonly property string highlightKeyNative: "native"
    readonly property string highlightKeyMastodon: "mastodon"
    property string highlightKey: highlightKeyNative

    property color activeHighlightColor: {
        if (highlightKey !== highlightKeyMastodon)
            return Theme.highlightColor
        return Theme.colorScheme === Theme.DarkOnLight ? "#5638cc" : "#a5abfd"
    }

    // hardcode the mastodon highlightbackground to something more pretty
    property color activeHighlightBackgroundColor: highlightKey === highlightKeyMastodon ? "#41337c" : Theme.highlightBackgroundColor

    property bool affectCover: true
    property bool affectTabBar: true

    property color baseColor: {
        if (colorKey === colorKeyMastodon)
            return Theme.colorScheme === Theme.DarkOnLight ? Theme.lightPrimaryColor : "#181820"
        var light = colorKey === colorKeySecondary ? Theme.lightSecondaryColor : Theme.lightPrimaryColor
        var dark = colorKey === colorKeySecondary ? Theme.darkSecondaryColor : Theme.darkPrimaryColor
        return Theme.colorScheme === Theme.DarkOnLight ? light : dark
    }

    property color backgroundColor: Theme.rgba(backgroundManager.baseColor, backgroundManager.opacity)

    function selectOpacity(value) {
        backgroundManager.opacity = value
        PreferenceStorage.saveBackgroundOpacity(value)
    }

    function selectColorKey(key) {
        backgroundManager.colorKey = key
        PreferenceStorage.saveBackgroundColorKey(key)
    }

    function selectHighlightKey(key) {
        backgroundManager.highlightKey = key
        PreferenceStorage.saveHighlightKey(key)
    }

    function selectAffectCover(enabled) {
        backgroundManager.affectCover = enabled
        PreferenceStorage.saveAffectCover(enabled)
    }

    function selectAffectTabBar(enabled) {
        backgroundManager.affectTabBar = enabled
        PreferenceStorage.saveAffectTabBar(enabled)
    }

    Component.onCompleted: {
        var saved = PreferenceStorage.loadBackgroundOpacity()
        if (saved !== "")
            backgroundManager.opacity = parseFloat(saved)

        var savedColorKey = PreferenceStorage.loadBackgroundColorKey()
        if (savedColorKey !== "")
            backgroundManager.colorKey = savedColorKey

        var savedHighlightKey = PreferenceStorage.loadHighlightKey()
        if (savedHighlightKey !== "")
            backgroundManager.highlightKey = savedHighlightKey

        var savedAffectCover = PreferenceStorage.loadAffectCover()
        if (savedAffectCover !== "")
            backgroundManager.affectCover = savedAffectCover === "1"

        var savedAffectTabBar = PreferenceStorage.loadAffectTabBar()
        if (savedAffectTabBar !== "")
            backgroundManager.affectTabBar = savedAffectTabBar === "1"
    }
}
