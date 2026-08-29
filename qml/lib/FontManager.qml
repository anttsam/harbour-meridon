pragma Singleton
import QtQuick 2.0
import Sailfish.Silica 1.0
import "FontPreferenceStorage.js" as FontPreferenceStorage

// App-wide font choice, applied to body text (AppLabel.qml) only - Silica's
// built-in widgets (Button, TextField, PageHeader, ...) have no support
// to take a font.family
QtObject {
    id: fontManager

    readonly property string keyDefault: "default"
    readonly property string keyUbuntu: "ubuntu"
    readonly property string keyFiraSans: "firasans"
    readonly property string keyOpenSans: "opensans"
    readonly property string keyRoboto: "roboto"
    readonly property string keyInter: "inter"

    property string selectedKey: keyDefault

    property bool lightWeight: false

    // customer fonts all render visibly larger than default
    readonly property real fontSizeMultiplierMin: 0.6
    readonly property real fontSizeMultiplierMax: 1.3
    property real fontSizeMultiplier: 1.0

    readonly property real lineHeightMultiplierMin: 0.8
    readonly property real lineHeightMultiplierMax: 1.5
    property real lineHeightMultiplier: 1.0

    // Single source of truth

    function familyForKey(key) {
        switch (key) {
        case keyUbuntu: return ubuntuRegular.name || Theme.fontFamily
        case keyFiraSans: return firaSansRegular.name || Theme.fontFamily
        case keyOpenSans: return openSansRegular.name || Theme.fontFamily
        case keyRoboto: return robotoRegular.name || Theme.fontFamily
        case keyInter: return interRegular.name || Theme.fontFamily
        default: return Theme.fontFamily
        }
    }
    function lightFamilyForKey(key) {
        switch (key) {
        case keyUbuntu: return ubuntuLight.status === FontLoader.Ready ? "Ubuntu Light" : familyForKey(key)
        case keyFiraSans: return firaSansLight.status === FontLoader.Ready ? "Fira Sans Light" : familyForKey(key)
        case keyOpenSans: return openSansLight.status === FontLoader.Ready ? "Open Sans Light" : familyForKey(key)
        case keyRoboto: return robotoLight.name || familyForKey(key)
        case keyInter: return interLight.status === FontLoader.Ready ? "Inter Light" : familyForKey(key)
        default: return familyForKey(key)
        }
    }

    property string activeFontFamily: lightWeight ? lightFamilyForKey(selectedKey) : familyForKey(selectedKey)
    property int activeFontWeight: lightWeight ? Font.Light : Font.Normal

    // Bold text always uses the regular (non-Light)
    property string activeBoldFontFamily: familyForKey(selectedKey)

    function logFontStatus(loader, label) {
        if (loader.status === FontLoader.Error)
            console.warn("[FontManager] failed to load font:", label)
    }

    property FontLoader ubuntuRegular: FontLoader {
        source: "../fonts/Ubuntu-Regular.ttf"
        onStatusChanged: fontManager.logFontStatus(ubuntuRegular, "Ubuntu Regular")
    }
    property FontLoader ubuntuBold: FontLoader {
        source: "../fonts/Ubuntu-Bold.ttf"
        onStatusChanged: fontManager.logFontStatus(ubuntuBold, "Ubuntu Bold")
    }
    property FontLoader ubuntuLight: FontLoader {
        source: "../fonts/Ubuntu-Light.ttf"
        onStatusChanged: fontManager.logFontStatus(ubuntuLight, "Ubuntu Light")
    }
    property FontLoader firaSansRegular: FontLoader {
        source: "../fonts/FiraSans-Regular.ttf"
        onStatusChanged: fontManager.logFontStatus(firaSansRegular, "Fira Sans Regular")
    }
    property FontLoader firaSansBold: FontLoader {
        source: "../fonts/FiraSans-Bold.ttf"
        onStatusChanged: fontManager.logFontStatus(firaSansBold, "Fira Sans Bold")
    }
    property FontLoader firaSansLight: FontLoader {
        source: "../fonts/FiraSans-Light.ttf"
        onStatusChanged: fontManager.logFontStatus(firaSansLight, "Fira Sans Light")
    }
    property FontLoader openSansRegular: FontLoader {
        source: "../fonts/OpenSans-Regular.ttf"
        onStatusChanged: fontManager.logFontStatus(openSansRegular, "Open Sans Regular")
    }
    property FontLoader openSansBold: FontLoader {
        source: "../fonts/OpenSans-Bold.ttf"
        onStatusChanged: fontManager.logFontStatus(openSansBold, "Open Sans Bold")
    }
    property FontLoader openSansLight: FontLoader {
        source: "../fonts/OpenSans-Light.ttf"
        onStatusChanged: fontManager.logFontStatus(openSansLight, "Open Sans Light")
    }
    property FontLoader robotoRegular: FontLoader {
        source: "../fonts/Roboto-Regular.ttf"
        onStatusChanged: fontManager.logFontStatus(robotoRegular, "Roboto Regular")
    }
    property FontLoader robotoBold: FontLoader {
        source: "../fonts/Roboto-Bold.ttf"
        onStatusChanged: fontManager.logFontStatus(robotoBold, "Roboto Bold")
    }
    property FontLoader robotoLight: FontLoader {
        source: "../fonts/Roboto-Light.ttf"
        onStatusChanged: fontManager.logFontStatus(robotoLight, "Roboto Light")
    }
    property FontLoader interRegular: FontLoader {
        source: "../fonts/Inter-Regular.ttf"
        onStatusChanged: fontManager.logFontStatus(interRegular, "Inter Regular")
    }
    property FontLoader interBold: FontLoader {
        source: "../fonts/Inter-Bold.ttf"
        onStatusChanged: fontManager.logFontStatus(interBold, "Inter Bold")
    }
    property FontLoader interLight: FontLoader {
        source: "../fonts/Inter-Light.ttf"
        onStatusChanged: fontManager.logFontStatus(interLight, "Inter Light")
    }

    function selectFont(key) {
        fontManager.selectedKey = key
        FontPreferenceStorage.saveFontChoice(key)
    }

    function selectFontSizeMultiplier(value) {
        fontManager.fontSizeMultiplier = value
        FontPreferenceStorage.saveFontSizeMultiplier(value)
    }

    function selectLineHeightMultiplier(value) {
        fontManager.lineHeightMultiplier = value
        FontPreferenceStorage.saveLineHeightMultiplier(value)
    }

    function selectLightWeight(enabled) {
        fontManager.lightWeight = enabled
        FontPreferenceStorage.saveLightWeight(enabled)
    }

    Component.onCompleted: {
        var saved = FontPreferenceStorage.loadFontChoice()
        if (saved)
            fontManager.selectedKey = saved

        var savedMultiplier = FontPreferenceStorage.loadFontSizeMultiplier()
        if (savedMultiplier)
            fontManager.fontSizeMultiplier = savedMultiplier

        var savedLineHeight = FontPreferenceStorage.loadLineHeightMultiplier()
        if (savedLineHeight)
            fontManager.lineHeightMultiplier = savedLineHeight

        var savedLightWeight = FontPreferenceStorage.loadLightWeight()
        if (savedLightWeight)
            fontManager.lightWeight = savedLightWeight === "1"
    }
}
