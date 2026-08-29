pragma Singleton
import QtQuick 2.0
import "PresetStorage.js" as PresetStorage
import "." as Lib

// Four fixed presets, never arbitrarily named/deleted: three with
// hard-coded "factory" values (Native/More contrast/Mastodon) and one
// (Custom) whose factory baseline is itself user-settable.

QtObject {
    id: presetManager

    readonly property string presetNative: "Native"
    readonly property string presetMoreContrast: "More contrast"
    readonly property string presetMastodon: "Mastodon"
    readonly property string presetCustom: "Custom"

    readonly property var presetNames: [presetNative, presetMoreContrast, presetMastodon, presetCustom]

    property string selectedPresetName: presetNative

    // Bumped by saveCustomFactory() purely so factoryValues()'s read of
    // it below gives the modified binding something reactive to depend on
    property int _customFactoryVersion: 0

    // True whenever the current live values differ from the selected
    // preset's own factory baseline - a plain property binding
    readonly property bool modified: !presetManager.valuesEqual(
        presetManager.currentValues(), presetManager.factoryValues(presetManager.selectedPresetName))

    function isBuiltIn(name) {
        return name === presetNative || name === presetMoreContrast || name === presetMastodon
    }

    function factoryValues(name) {
        if (name === presetNative) {
            return {
                fontKey: Lib.FontManager.keyDefault,
                lightWeight: false,
                fontSizeMultiplier: 1.0,
                lineHeightMultiplier: 1.0,
                colorKey: Lib.BackgroundManager.colorKeyPrimary,
                opacity: 0.0,
                affectCover: false,
                affectTabBar: false,
                highlightKey: Lib.BackgroundManager.highlightKeyNative
            }
        }
        if (name === presetMoreContrast) {
            return {
                fontKey: Lib.FontManager.keyInter,
                lightWeight: true,
                fontSizeMultiplier: 0.85,
                lineHeightMultiplier: 1.10,
                colorKey: Lib.BackgroundManager.colorKeyPrimary,
                opacity: 0.5,
                affectCover: true,
                affectTabBar: true,
                highlightKey: Lib.BackgroundManager.highlightKeyNative
            }
        }
        if (name === presetMastodon) {
            return {
                fontKey: Lib.FontManager.keyInter,
                lightWeight: true,
                fontSizeMultiplier: 0.85,
                lineHeightMultiplier: 1.10,
                colorKey: Lib.BackgroundManager.colorKeyMastodon,
                opacity: 0.9,
                affectCover: true,
                affectTabBar: false,
                highlightKey: Lib.BackgroundManager.highlightKeyMastodon
            }
        }
        if (name === presetCustom) {
            var v = presetManager._customFactoryVersion // establishes the reactive dependency described above
            var stored = PresetStorage.loadCustomFactory()
            return stored ? JSON.parse(stored) : presetManager.factoryValues(presetManager.presetNative)
        }
        return null
    }

    function currentValues() {
        return {
            fontKey: Lib.FontManager.selectedKey,
            lightWeight: Lib.FontManager.lightWeight,
            fontSizeMultiplier: Lib.FontManager.fontSizeMultiplier,
            lineHeightMultiplier: Lib.FontManager.lineHeightMultiplier,
            colorKey: Lib.BackgroundManager.colorKey,
            opacity: Lib.BackgroundManager.opacity,
            affectCover: Lib.BackgroundManager.affectCover,
            affectTabBar: Lib.BackgroundManager.affectTabBar,
            highlightKey: Lib.BackgroundManager.highlightKey
        }
    }

    function valuesEqual(a, b) {
        if (!a || !b)
            return false
        for (var key in a) {
            if (a[key] !== b[key])
                return false
        }
        return true
    }

    function applyValues(values) {
        Lib.FontManager.selectFont(values.fontKey)
        Lib.FontManager.selectLightWeight(values.lightWeight)
        Lib.FontManager.selectFontSizeMultiplier(values.fontSizeMultiplier)
        Lib.FontManager.selectLineHeightMultiplier(values.lineHeightMultiplier)
        Lib.BackgroundManager.selectColorKey(values.colorKey)
        Lib.BackgroundManager.selectOpacity(values.opacity)
        Lib.BackgroundManager.selectAffectCover(values.affectCover)
        Lib.BackgroundManager.selectAffectTabBar(values.affectTabBar)
        //fallback
        Lib.BackgroundManager.selectHighlightKey(values.highlightKey || Lib.BackgroundManager.highlightKeyNative)
    }

    function applyPreset(name) {
        var saved = PresetStorage.loadPreset(name)
        var values = saved ? JSON.parse(saved) : factoryValues(name)
        if (!values)
            return

        applyValues(values)
        presetManager.selectedPresetName = name
        PresetStorage.saveSelectedPresetName(name)
    }

    // Called from SettingsPage.qml when the page is closed
    function persistCurrentAsModified() {
        PresetStorage.savePreset(presetManager.selectedPresetName, JSON.stringify(presetManager.currentValues()))
    }

    // The "Reset" button in SettingsPage.qml
    function resetSelected() {
        var factory = presetManager.factoryValues(presetManager.selectedPresetName)
        PresetStorage.savePreset(presetManager.selectedPresetName, JSON.stringify(factory))
        applyValues(factory)
    }

    // Overwrites Custom's own factorybaseline with the current live values
    function saveCustomFactory() {
        var values = presetManager.currentValues()
        PresetStorage.saveCustomFactory(JSON.stringify(values))
        presetManager._customFactoryVersion += 1
        PresetStorage.savePreset(presetManager.presetCustom, JSON.stringify(values))
    }

    Component.onCompleted: {
        var saved = PresetStorage.loadSelectedPresetName()
        if (saved !== "" && presetManager.presetNames.indexOf(saved) !== -1)
            presetManager.selectedPresetName = saved
    }
}
