import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib
import "../../lib/SessionManager.js" as SessionManager
import "../../lib/EmojiCodepoints.js" as EmojiCodepoints
import "../../lib/EmojiRecentStorage.js" as EmojiRecentStorage

// Emoji picker

Dialog {
    id: emojiPickerDialog

    backgroundColor: AppLib.BackgroundManager.backgroundColor
    palette.highlightColor: AppLib.BackgroundManager.activeHighlightColor
    palette.highlightBackgroundColor: AppLib.BackgroundManager.activeHighlightBackgroundColor

    property string selectedShortcode: ""
    property string selectedChar: ""
    canAccept: selectedShortcode.length > 0 || selectedChar.length > 0

    // What ComposePage actually inserts once accepted
    readonly property string insertText: (selectedShortcode.length > 0
        ? (":" + selectedShortcode + ":") : selectedChar) + " "

    property var customEmojis: [] // [{shortcode, url}], this instance's full set
    property bool customLoading: true
    property string customError: ""

    property var recentEmojis: [] // EmojiRecentStorage entries, most recent first

    property string searchQuery: ""

    readonly property int cellSize: Theme.itemSizeMedium

    // setting thi is trying to fix loaded from bottom, but it doesn't work..
    readonly property int gridColumns: width > 0
        ? Math.max(1, Math.floor((width - 2 * Theme.horizontalPageMargin) / cellSize))
        : 5

    function matchesQuery(name, shortcode) {
        if (emojiPickerDialog.searchQuery.length === 0)
            return true
        return (!!name && name.toLowerCase().indexOf(emojiPickerDialog.searchQuery) !== -1)
            || (!!shortcode && shortcode.toLowerCase().indexOf(emojiPickerDialog.searchQuery) !== -1)
    }

    readonly property var filteredRecentEmojis: emojiPickerDialog.recentEmojis.filter(function(e) {
        return e.kind === "custom"
            ? emojiPickerDialog.matchesQuery("", e.shortcode)
            : emojiPickerDialog.matchesQuery(EmojiCodepoints.nameForCode(e.code || ""), "")
    })

    readonly property var filteredCustomEmojis: emojiPickerDialog.customEmojis.filter(function(e) {
        return emojiPickerDialog.matchesQuery("", e.shortcode)
    })

    readonly property var filteredFlagPairs: EmojiCodepoints.flagPairs().filter(function(pair) {
        return emojiPickerDialog.matchesQuery(EmojiCodepoints.flagName(pair[0], pair[1]), "")
    })

    onAccepted: {
        var entry = emojiPickerDialog.selectedShortcode.length > 0
            ? { kind: "custom", shortcode: emojiPickerDialog.selectedShortcode,
                url: (emojiPickerDialog._selectedCustomUrl || "") }
            : { kind: "unicode", char: emojiPickerDialog.selectedChar,
                url: (emojiPickerDialog._selectedCharUrl || ""),
                code: (emojiPickerDialog._selectedCharCode || "") }
        EmojiRecentStorage.recordUsed(entry)
    }

    // Set alongside selectedShortcode/selectedChar so onAccepted gets it straight away
    property string _selectedCustomUrl: ""
    property string _selectedCharUrl: ""
    property string _selectedCharCode: ""

    Component.onCompleted: {
        recentEmojis = EmojiRecentStorage.loadRecent()
        loadCustomEmojis()
    }

    function loadCustomEmojis() {
        SessionManager.authenticatedRequest("GET", "/api/v1/custom_emojis", null,
            function(response) {
                customLoading = false
                customEmojis = (response || []).filter(function(e) {
                    return e.visible_in_picker !== false
                })
            },
            function(status, message) {
                customLoading = false
                // Not every instance has custom emoji, fails quietly into just
                // showing the bundled Unicode set instead
                customError = message || String(status)
                console.warn("[EmojiPicker] couldn't load custom emojis:", status, message)
            }
        )
    }

    function selectShortcode(shortcode, url) {
        emojiPickerDialog.selectedChar = ""
        emojiPickerDialog._selectedCharUrl = ""
        emojiPickerDialog._selectedCharCode = ""
        emojiPickerDialog.selectedShortcode = shortcode
        emojiPickerDialog._selectedCustomUrl = url
    }

    function selectChar(ch, url, code) {
        emojiPickerDialog.selectedShortcode = ""
        emojiPickerDialog._selectedCustomUrl = ""
        emojiPickerDialog.selectedChar = ch
        emojiPickerDialog._selectedCharUrl = url
        emojiPickerDialog._selectedCharCode = code || ""
    }

    Component {
        id: cellHighlight

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.paddingSmall / 2
            radius: Theme.paddingSmall
            color: Theme.rgba(palette.highlightColor, 0.25)
            border.width: 2
            border.color: palette.highlightColor
        }
    }

    SilicaFlickable {
        id: pickerFlickable
        anchors.fill: parent
        contentHeight: column.height

        Component.onCompleted: contentY = 0

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                acceptText: qsTr("Insert")
            }

            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search emoji")
                onTextChanged: emojiPickerDialog.searchQuery = text.trim().toLowerCase()
            }

            SectionHeader {
                text: qsTr("Last used")
                visible: emojiPickerDialog.filteredRecentEmojis.length > 0
            }

            GridView {
                id: recentGrid
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: Math.ceil(count / emojiPickerDialog.gridColumns) * emojiPickerDialog.cellSize
                visible: emojiPickerDialog.filteredRecentEmojis.length > 0
                interactive: false
                verticalLayoutDirection: GridView.TopToBottom
                cacheBuffer: 0
                cellWidth: emojiPickerDialog.cellSize
                cellHeight: emojiPickerDialog.cellSize
                model: emojiPickerDialog.filteredRecentEmojis

                delegate: Item {
                    id: recentDelegate
                    width: recentGrid.cellWidth
                    height: recentGrid.cellHeight

                    readonly property bool isCustom: modelData.kind === "custom"

                    Loader {
                        anchors.fill: parent
                        active: recentDelegate.isCustom
                            ? emojiPickerDialog.selectedShortcode === modelData.shortcode
                            : emojiPickerDialog.selectedChar === modelData.char
                        sourceComponent: cellHighlight
                    }

                    Image {
                        anchors.centerIn: parent
                        width: Theme.iconSizeMedium
                        height: width
                        source: modelData.url
                        asynchronous: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (recentDelegate.isCustom)
                                emojiPickerDialog.selectShortcode(modelData.shortcode, modelData.url)
                            else
                                emojiPickerDialog.selectChar(modelData.char, modelData.url, modelData.code)
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("Custom")
                visible: emojiPickerDialog.filteredCustomEmojis.length > 0
            }

            GridView {
                id: customGrid
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: Math.ceil(count / emojiPickerDialog.gridColumns) * emojiPickerDialog.cellSize
                visible: emojiPickerDialog.filteredCustomEmojis.length > 0
                interactive: false
                verticalLayoutDirection: GridView.TopToBottom
                cacheBuffer: 0
                cellWidth: emojiPickerDialog.cellSize
                cellHeight: emojiPickerDialog.cellSize
                model: emojiPickerDialog.filteredCustomEmojis

                delegate: Item {
                    width: customGrid.cellWidth
                    height: customGrid.cellHeight

                    readonly property string cellUrl: modelData.static_url || modelData.url

                    Loader {
                        anchors.fill: parent
                        active: emojiPickerDialog.selectedShortcode === modelData.shortcode
                        sourceComponent: cellHighlight
                    }

                    Image {
                        anchors.centerIn: parent
                        width: Theme.iconSizeMedium
                        height: width
                        source: parent.cellUrl
                        asynchronous: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: emojiPickerDialog.selectShortcode(modelData.shortcode, parent.cellUrl)
                    }
                }
            }

            AppLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                visible: emojiPickerDialog.customLoading
                text: qsTr("Loading this server's emoji…")
            }

            // One SectionHeader + GridView pair per CLDR group
            Repeater {
                model: EmojiCodepoints.groupedCodepoints()

                delegate: Column {
                    id: groupColumn
                    width: column.width
                    spacing: Theme.paddingMedium

                    readonly property var filteredCodes: modelData.codes.filter(function(hex) {
                        return emojiPickerDialog.matchesQuery(EmojiCodepoints.emojiName(hex), "")
                    })
                    visible: filteredCodes.length > 0

                    SectionHeader {
                        text: modelData.group
                    }

                    GridView {
                        id: groupGrid
                        x: Theme.horizontalPageMargin
                        width: groupColumn.width - 2 * Theme.horizontalPageMargin
                        height: Math.ceil(count / emojiPickerDialog.gridColumns) * emojiPickerDialog.cellSize
                        interactive: false
                        verticalLayoutDirection: GridView.TopToBottom
                        cacheBuffer: 0
                        cellWidth: emojiPickerDialog.cellSize
                        cellHeight: emojiPickerDialog.cellSize
                        model: groupColumn.filteredCodes

                        delegate: Item {
                            id: unicodeDelegate
                            width: groupGrid.cellWidth
                            height: groupGrid.cellHeight

                            readonly property string ch: AppLib.EmojiManager.codepointToChar(modelData)
                            readonly property string cellUrl: AppLib.EmojiManager.unicodeImageUrl(modelData)

                            Loader {
                                anchors.fill: parent
                                active: emojiPickerDialog.selectedChar === unicodeDelegate.ch
                                sourceComponent: cellHighlight
                            }

                            Image {
                                anchors.centerIn: parent
                                width: Theme.iconSizeMedium
                                height: width
                                source: unicodeDelegate.cellUrl
                                asynchronous: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: emojiPickerDialog.selectChar(unicodeDelegate.ch, unicodeDelegate.cellUrl, modelData)
                            }
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("Flags")
                visible: emojiPickerDialog.filteredFlagPairs.length > 0
            }

            GridView {
                id: flagGrid
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: Math.ceil(count / emojiPickerDialog.gridColumns) * emojiPickerDialog.cellSize
                visible: emojiPickerDialog.filteredFlagPairs.length > 0
                interactive: false
                verticalLayoutDirection: GridView.TopToBottom
                cacheBuffer: 0
                cellWidth: emojiPickerDialog.cellSize
                cellHeight: emojiPickerDialog.cellSize
                model: emojiPickerDialog.filteredFlagPairs

                delegate: Item {
                    id: flagDelegate
                    width: flagGrid.cellWidth
                    height: flagGrid.cellHeight

                    readonly property string ch: AppLib.EmojiManager.codepointToChar(modelData[0])
                        + AppLib.EmojiManager.codepointToChar(modelData[1])
                    readonly property string cellUrl: AppLib.EmojiManager.flagImageUrl(modelData[0], modelData[1])

                    Loader {
                        anchors.fill: parent
                        active: emojiPickerDialog.selectedChar === flagDelegate.ch
                        sourceComponent: cellHighlight
                    }

                    Image {
                        anchors.centerIn: parent
                        width: Theme.iconSizeMedium
                        height: width
                        source: flagDelegate.cellUrl
                        asynchronous: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: emojiPickerDialog.selectChar(
                            flagDelegate.ch, flagDelegate.cellUrl, modelData[0] + "-" + modelData[1])
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
