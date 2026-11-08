import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib" as AppLib

AppPage {
    id: appearancePage

    readonly property var fontKeys: [
        AppLib.FontManager.keyDefault,
        AppLib.FontManager.keyFiraSans,
        AppLib.FontManager.keyOpenSans,
        AppLib.FontManager.keyRoboto,
        AppLib.FontManager.keyInter
    ]

    function previewFamily(key) {
        return AppLib.FontManager.lightWeight
            ? AppLib.FontManager.lightFamilyForKey(key)
            : AppLib.FontManager.familyForKey(key)
    }

    // auto apply on exit
    onStatusChanged: {
        if (status === PageStatus.Deactivating)
            AppLib.PresetManager.persistCurrentAsModified()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: qsTr("Appearance")
            }

            SettingsCombo {
                label: qsTr("Preset")
                value: AppLib.PresetManager.selectedPresetName
                    + (AppLib.PresetManager.modified ? qsTr(" (modified)") : "")
                manager: AppLib.PresetManager
                key: "selectedPresetName"
                setter: "applyPreset"
                keys: AppLib.PresetManager.presetNames
                labels: AppLib.PresetManager.presetNames
            }

            // Only while there is something to save or undo
            Row {
                visible: AppLib.PresetManager.modified
                height: visible ? childrenRect.height : 0
                spacing: Theme.paddingSmall
                anchors.horizontalCenter: parent.horizontalCenter

                Button {
                    text: qsTr("Save preset")
                    visible: AppLib.PresetManager.selectedPresetName === AppLib.PresetManager.presetCustom
                    onClicked: AppLib.PresetManager.saveCustomFactory()
                }

                Button {
                    text: qsTr("Reset changes")
                    onClicked: AppLib.PresetManager.resetSelected()
                }
            }

            SettingsPreview {}

            ExpandingSection {
                id: fineTune
                title: qsTr("Fine-tune")

                content.sourceComponent: Column {
                    width: fineTune.width

                    SectionHeader { text: qsTr("Text") }

                    SettingsCombo {
                        label: qsTr("Font")
                        manager: AppLib.FontManager
                        key: "selectedKey"
                        setter: "selectFont"
                        keys: appearancePage.fontKeys
                        labels: [qsTr("Default"), qsTr("Fira Sans"), qsTr("Open Sans"), qsTr("Roboto"), qsTr("Inter")]
                        fontFamilies: [
                            Theme.fontFamily,
                            appearancePage.previewFamily(AppLib.FontManager.keyFiraSans),
                            appearancePage.previewFamily(AppLib.FontManager.keyOpenSans),
                            appearancePage.previewFamily(AppLib.FontManager.keyRoboto),
                            appearancePage.previewFamily(AppLib.FontManager.keyInter)
                        ]
                        fontWeight: AppLib.FontManager.activeFontWeight
                    }

                    SettingsSwitch {
                        width: parent.width
                        text: qsTr("Light weight")
                        description: qsTr("Use a lighter weight where the font has one.")
                        manager: AppLib.FontManager
                        key: "lightWeight"
                        setter: "selectLightWeight"
                    }

                    SettingsSlider {
                        label: qsTr("Text size")
                        minimumValue: AppLib.FontManager.fontSizeMultiplierMin
                        maximumValue: AppLib.FontManager.fontSizeMultiplierMax
                        manager: AppLib.FontManager
                        key: "fontSizeMultiplier"
                        setter: "selectFontSizeMultiplier"
                    }

                    SettingsSlider {
                        label: qsTr("Line spacing")
                        minimumValue: AppLib.FontManager.lineHeightMultiplierMin
                        maximumValue: AppLib.FontManager.lineHeightMultiplierMax
                        manager: AppLib.FontManager
                        key: "lineHeightMultiplier"
                        setter: "selectLineHeightMultiplier"
                    }

                    SectionHeader { text: qsTr("Colors") }

                    SettingsCombo {
                        label: qsTr("Highlight color")
                        description: qsTr("Native follows your Ambience.")
                        manager: AppLib.BackgroundManager
                        key: "highlightKey"
                        setter: "selectHighlightKey"
                        keys: [
                            AppLib.BackgroundManager.highlightKeyNative,
                            AppLib.BackgroundManager.highlightKeyMastodon
                        ]
                        labels: [qsTr("Native"), qsTr("Mastodon")]
                    }

                    SettingsCombo {
                        label: qsTr("Overlay color")
                        manager: AppLib.BackgroundManager
                        key: "colorKey"
                        setter: "selectColorKey"
                        keys: [
                            AppLib.BackgroundManager.colorKeyPrimary,
                            AppLib.BackgroundManager.colorKeySecondary,
                            AppLib.BackgroundManager.colorKeyMastodon
                        ]
                        labels: [qsTr("Primary"), qsTr("Secondary"), qsTr("Mastodon")]
                    }

                    SettingsSlider {
                        label: qsTr("Overlay intensity")
                        minimumValue: AppLib.BackgroundManager.opacityMin
                        maximumValue: AppLib.BackgroundManager.opacityMax
                        manager: AppLib.BackgroundManager
                        key: "opacity"
                        setter: "selectOpacity"
                    }

                    SettingsSwitch {
                        width: parent.width
                        text: qsTr("Overlay on navigation bar")
                        manager: AppLib.BackgroundManager
                        key: "affectTabBar"
                        setter: "selectAffectTabBar"
                    }

                    SettingsSwitch {
                        width: parent.width
                        text: qsTr("Overlay on cover")
                        manager: AppLib.BackgroundManager
                        key: "affectCover"
                        setter: "selectAffectCover"
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
