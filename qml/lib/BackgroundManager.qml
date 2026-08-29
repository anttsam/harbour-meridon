pragma Singleton
import QtQuick 2.0
import Sailfish.Silica 1.0
import "FontPreferenceStorage.js" as FontPreferenceStorage

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
        FontPreferenceStorage.saveBackgroundOpacity(value)
    }

    function selectColorKey(key) {
        backgroundManager.colorKey = key
        FontPreferenceStorage.saveBackgroundColorKey(key)
    }

    function selectHighlightKey(key) {
        backgroundManager.highlightKey = key
        FontPreferenceStorage.saveHighlightKey(key)
    }

    function selectAffectCover(enabled) {
        backgroundManager.affectCover = enabled
        FontPreferenceStorage.saveAffectCover(enabled)
    }

    function selectAffectTabBar(enabled) {
        backgroundManager.affectTabBar = enabled
        FontPreferenceStorage.saveAffectTabBar(enabled)
    }

    Component.onCompleted: {
        var saved = FontPreferenceStorage.loadBackgroundOpacity()
        if (saved !== "")
            backgroundManager.opacity = parseFloat(saved)

        var savedColorKey = FontPreferenceStorage.loadBackgroundColorKey()
        if (savedColorKey !== "")
            backgroundManager.colorKey = savedColorKey

        var savedHighlightKey = FontPreferenceStorage.loadHighlightKey()
        if (savedHighlightKey !== "")
            backgroundManager.highlightKey = savedHighlightKey

        var savedAffectCover = FontPreferenceStorage.loadAffectCover()
        if (savedAffectCover !== "")
            backgroundManager.affectCover = savedAffectCover === "1"

        var savedAffectTabBar = FontPreferenceStorage.loadAffectTabBar()
        if (savedAffectTabBar !== "")
            backgroundManager.affectTabBar = savedAffectTabBar === "1"
    }
}
