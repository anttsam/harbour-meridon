import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib" as AppLib
import "../lib/SessionManager.js" as SessionManager

AppPage {
    id: settingsPage

    property var fontKeys: [
        AppLib.FontManager.keyDefault,
        AppLib.FontManager.keyFiraSans,
        AppLib.FontManager.keyOpenSans,
        AppLib.FontManager.keyRoboto,
        AppLib.FontManager.keyInter
    ]

    property var backgroundColorKeys: [
        AppLib.BackgroundManager.colorKeyPrimary,
        AppLib.BackgroundManager.colorKeySecondary,
        AppLib.BackgroundManager.colorKeyMastodon
    ]

    property var highlightKeys: [
        AppLib.BackgroundManager.highlightKeyNative,
        AppLib.BackgroundManager.highlightKeyMastodon
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
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: qsTr("Log out")
                onClicked: {
                    Remorse.popupAction(settingsPage, qsTr("Logging out"), function() {
                        SessionManager.clearSession()
                        pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
                    })
                }
            }
            /*MenuItem {
                // Only Custom's own factory baseline is user-settable -
                // the other three are hard-coded (see
                // PresetManager.qml's factoryValues()).
                text: qsTr("Save preset")
                visible: AppLib.PresetManager.selectedPresetName === AppLib.PresetManager.presetCustom
                onClicked: AppLib.PresetManager.saveCustomFactory()
            }*/
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingSmall
            PageHeader {
                title: qsTr("Settings")
            }

            TextSwitch {
                id: renderEmojisSwitch
                width: parent.width
                text: qsTr("Render colorful emojis")
                description: qsTr("Shows both each server's own custom emoji and standard Unicode emoji as colorful images in post text and display names, instead of plain :shortcode: text or the platform's flat emoji glyphs.")
                checked: AppLib.EmojiManager.renderEmojis
                onCheckedChanged: AppLib.EmojiManager.selectRenderEmojis(checked)
            }

            TextSwitch {
                id: autoplayGifsSwitch
                width: parent.width
                text: qsTr("Autoplay GIFs")
                description: qsTr("Plays GIF attachments automatically as they scroll into view, without needing a tap first.")
                checked: AppLib.VideoManager.autoplayGifs
                onCheckedChanged: AppLib.VideoManager.selectAutoplayGifs(checked)
                Connections {
                    target: AppLib.VideoManager
                    onAutoplayGifsChanged: {
                        if (autoplayGifsSwitch.checked !== AppLib.VideoManager.autoplayGifs)
                            autoplayGifsSwitch.checked = AppLib.VideoManager.autoplayGifs
                    }
                }
            }

            SectionHeader { text: qsTr("Theme") }

            ComboBox {
                id: presetSelector
                width: parent.width
                label: qsTr("Preset")
                currentIndex: AppLib.PresetManager.presetNames.indexOf(AppLib.PresetManager.selectedPresetName)

                value: AppLib.PresetManager.selectedPresetName
                    + (AppLib.PresetManager.modified ? qsTr(" (modified)") : "")
                menu: ContextMenu {
                    Repeater {
                        model: AppLib.PresetManager.presetNames
                        MenuItem { text: modelData }
                    }
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        AppLib.PresetManager.applyPreset(AppLib.PresetManager.presetNames[currentIndex])
                }
                Connections {
                    target: AppLib.PresetManager
                    onSelectedPresetNameChanged: {
                        var idx = AppLib.PresetManager.presetNames.indexOf(AppLib.PresetManager.selectedPresetName)
                        if (presetSelector.currentIndex !== idx)
                            presetSelector.currentIndex = idx
                    }
                }
            }
            Row {
                //width: parent.width
                height: childrenRect.height
                spacing: Theme.paddingSmall
                anchors.horizontalCenter: parent.horizontalCenter
                Button {
                    text: qsTr("Save preset")
                    visible: AppLib.PresetManager.selectedPresetName === AppLib.PresetManager.presetCustom
                    onClicked: AppLib.PresetManager.saveCustomFactory()
                    //anchors.horizontalCenter: parent.horizontalCenter
                    enabled: AppLib.PresetManager.modified
                }


                Button {
                    text: qsTr("Reset changes")
                    //anchors.horizontalCenter: parent.horizontalCenter
                    enabled: AppLib.PresetManager.modified
                    onClicked: AppLib.PresetManager.resetSelected()
                }
            }

            SectionHeader { text: qsTr("Font") }


            ComboBox {
                id: fontSelector
                width: parent.width
                label: qsTr("Post text font:")
                currentIndex: settingsPage.fontKeys.indexOf(AppLib.FontManager.selectedKey)

                menu: ContextMenu {
                    MenuItem { text: qsTr("Default") }
                    MenuItem {
                        text: qsTr("Fira Sans")
                        font.family: settingsPage.previewFamily(AppLib.FontManager.keyFiraSans)
                        font.weight: AppLib.FontManager.activeFontWeight
                    }
                    MenuItem {
                        text: qsTr("Open Sans")
                        font.family: settingsPage.previewFamily(AppLib.FontManager.keyOpenSans)
                        font.weight: AppLib.FontManager.activeFontWeight
                    }
                    MenuItem {
                        text: qsTr("Roboto")
                        font.family: settingsPage.previewFamily(AppLib.FontManager.keyRoboto)
                        font.weight: AppLib.FontManager.activeFontWeight
                    }
                    MenuItem {
                        text: qsTr("Inter")
                        font.family: settingsPage.previewFamily(AppLib.FontManager.keyInter)
                        font.weight: AppLib.FontManager.activeFontWeight
                    }
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        AppLib.FontManager.selectFont(settingsPage.fontKeys[currentIndex])
                }
                Connections {
                    target: AppLib.FontManager
                    onSelectedKeyChanged: {
                        var idx = settingsPage.fontKeys.indexOf(AppLib.FontManager.selectedKey)
                        if (fontSelector.currentIndex !== idx)
                            fontSelector.currentIndex = idx
                    }
                }
            }

            TextSwitch {
                id: lightWeightSwitch
                width: parent.width
                text: qsTr("Light weight")
                description: qsTr("Uses a lighter weight of the selected font, where available.")
                checked: AppLib.FontManager.lightWeight
                onCheckedChanged: AppLib.FontManager.selectLightWeight(checked)
                Connections {
                    target: AppLib.FontManager
                    onLightWeightChanged: {
                        if (lightWeightSwitch.checked !== AppLib.FontManager.lightWeight)
                            lightWeightSwitch.checked = AppLib.FontManager.lightWeight
                    }
                }
            }

            AppLabel {
                useCustomFont: true
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Applies to post and profile text right away. Buttons and headers keep the system font.")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
            }

            Slider {
                id: fontSizeSlider
                width: parent.width
                minimumValue: AppLib.FontManager.fontSizeMultiplierMin
                maximumValue: AppLib.FontManager.fontSizeMultiplierMax
                stepSize: 0.05
                value: AppLib.FontManager.fontSizeMultiplier
                valueText: Math.round(value * 100) + "%"
                label: qsTr("Text size")
                onValueChanged: AppLib.FontManager.selectFontSizeMultiplier(value)
                Connections {
                    target: AppLib.FontManager
                    onFontSizeMultiplierChanged: {
                        if (fontSizeSlider.value !== AppLib.FontManager.fontSizeMultiplier)
                            fontSizeSlider.value = AppLib.FontManager.fontSizeMultiplier
                    }
                }
            }

            Slider {
                id: lineHeightSlider
                width: parent.width
                minimumValue: AppLib.FontManager.lineHeightMultiplierMin
                maximumValue: AppLib.FontManager.lineHeightMultiplierMax
                stepSize: 0.05
                value: AppLib.FontManager.lineHeightMultiplier
                valueText: Math.round(value * 100) + "%"
                label: qsTr("Line spacing")
                onValueChanged: AppLib.FontManager.selectLineHeightMultiplier(value)
                Connections {
                    target: AppLib.FontManager
                    onLineHeightMultiplierChanged: {
                        if (lineHeightSlider.value !== AppLib.FontManager.lineHeightMultiplier)
                            lineHeightSlider.value = AppLib.FontManager.lineHeightMultiplier
                    }
                }
            }


            SectionHeader { text: qsTr("Background and highlights") }

            ComboBox {
                id: highlightColorSelector
                width: parent.width
                label: qsTr("Highlights color:")
                currentIndex: settingsPage.highlightKeys.indexOf(AppLib.BackgroundManager.highlightKey)
                menu: ContextMenu {
                    MenuItem { text: qsTr("Native") }
                    MenuItem { text: qsTr("Mastodon") }
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        AppLib.BackgroundManager.selectHighlightKey(settingsPage.highlightKeys[currentIndex])
                }
                Connections {
                    target: AppLib.BackgroundManager
                    onHighlightKeyChanged: {
                        var idx = settingsPage.highlightKeys.indexOf(AppLib.BackgroundManager.highlightKey)
                        if (highlightColorSelector.currentIndex !== idx)
                            highlightColorSelector.currentIndex = idx
                    }
                }
            }

            ComboBox {
                id: backgroundColorSelector
                width: parent.width
                label: qsTr("Background overlay color:")
                currentIndex: settingsPage.backgroundColorKeys.indexOf(AppLib.BackgroundManager.colorKey)
                menu: ContextMenu {
                    MenuItem { text: qsTr("Primary") }
                    MenuItem { text: qsTr("Secondary") }
                    MenuItem { text: qsTr("Mastodon") }
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        AppLib.BackgroundManager.selectColorKey(settingsPage.backgroundColorKeys[currentIndex])
                }
                Connections {
                    target: AppLib.BackgroundManager
                    onColorKeyChanged: {
                        var idx = settingsPage.backgroundColorKeys.indexOf(AppLib.BackgroundManager.colorKey)
                        if (backgroundColorSelector.currentIndex !== idx)
                            backgroundColorSelector.currentIndex = idx
                    }
                }
            }

            Slider {
                id: backgroundOpacitySlider
                width: parent.width
                minimumValue: AppLib.BackgroundManager.opacityMin
                maximumValue: AppLib.BackgroundManager.opacityMax
                stepSize: 0.05
                value: AppLib.BackgroundManager.opacity
                valueText: Math.round(value * 100) + "%"
                label: qsTr("Overlay intesity")
                onValueChanged: AppLib.BackgroundManager.selectOpacity(value)
                Connections {
                    target: AppLib.BackgroundManager
                    onOpacityChanged: {
                        if (backgroundOpacitySlider.value !== AppLib.BackgroundManager.opacity)
                            backgroundOpacitySlider.value = AppLib.BackgroundManager.opacity
                    }
                }
            }


            TextSwitch {
                id: affectTabBarSwitch
                width: parent.width
                text: qsTr("Apply overlay to Navigation bar")
                checked: AppLib.BackgroundManager.affectTabBar
                onCheckedChanged: AppLib.BackgroundManager.selectAffectTabBar(checked)
                Connections {
                    target: AppLib.BackgroundManager
                    onAffectTabBarChanged: {
                        if (affectTabBarSwitch.checked !== AppLib.BackgroundManager.affectTabBar)
                            affectTabBarSwitch.checked = AppLib.BackgroundManager.affectTabBar
                    }
                }
            }
            TextSwitch {
                id: affectCoverSwitch
                width: parent.width
                text: qsTr("Apply overlay to cover")
                checked: AppLib.BackgroundManager.affectCover
                onCheckedChanged: AppLib.BackgroundManager.selectAffectCover(checked)
                Connections {
                    target: AppLib.BackgroundManager
                    onAffectCoverChanged: {
                        if (affectCoverSwitch.checked !== AppLib.BackgroundManager.affectCover)
                            affectCoverSwitch.checked = AppLib.BackgroundManager.affectCover
                    }
                }
            }

        }

        VerticalScrollDecorator {}
    }
}
