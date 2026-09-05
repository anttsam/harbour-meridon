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
    readonly property int jumpCellSize: Theme.iconSizeMedium + Theme.paddingMedium

    // One entry per section header that'll actually appear in rowsModel -
    // built once (static data, doesn't depend on search/custom-emoji
    // loading), each carrying either a theme icon (Last used/Custom) or an
    // emoji image (reusing EmojiManager's same image URLs the grid itself
    // uses - this app renders emoji as images rather than font glyphs
    // throughout, since Sailfish's UI font doesn't reliably cover them).
    readonly property var jumpTargets: buildJumpTargets()

    function buildJumpTargets() {
        var targets = []
        targets.push({ category: qsTr("Last used"), iconSource: "image://theme/icon-m-clock", imageUrl: "" })
        targets.push({ category: qsTr("Custom"), iconSource: "image://theme/icon-m-favorite", imageUrl: "" })

        var groups = EmojiCodepoints.groupedCodepoints()
        for (var g = 0; g < groups.length; g++) {
            // The tiny 4-symbol "Flags" group right before the real,
            // qsTr("Flags")-labeled country flags below shares that same
            // category label, so it's already covered by that one combined
            // jump target rather than needing its own.
            if (groups[g].group === "Flags" || groups[g].codes.length === 0)
                continue
            targets.push({ category: groups[g].group, iconSource: "",
                imageUrl: AppLib.EmojiManager.unicodeImageUrl(groups[g].codes[0]) })
        }

        var flags = EmojiCodepoints.flagPairs()
        if (flags.length > 0) {
            targets.push({ category: qsTr("Flags"), iconSource: "",
                imageUrl: AppLib.EmojiManager.flagImageUrl(flags[0][0], flags[0][1]) })
        }
        return targets
    }

    // category -> index of that category's first row in rowsModel, rebuilt
    // alongside rowsModel itself. Read only imperatively (scrollToCategory,
    // triggered from a click), never bound to declaratively, so it being a
    // plain JS object rather than a real QML property is fine here.
    property var categoryIndex: ({})

    function scrollToCategory(category) {
        var idx = emojiPickerDialog.categoryIndex[category]
        if (idx === undefined || idx < 0 || idx >= rowsModel.count)
            return
        pickerListView.positionViewAtIndex(idx, ListView.Beginning)
    }

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
        rebuildRows()
        loadCustomEmojis()
    }

    onSearchQueryChanged: rebuildRows()
    onGridColumnsChanged: rebuildRows()

    function loadCustomEmojis() {
        SessionManager.authenticatedRequest("GET", "/api/v1/custom_emojis", null,
            function(response) {
                customLoading = false
                customEmojis = (response || []).filter(function(e) {
                    return e.visible_in_picker !== false
                })
                rebuildRows()
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

    function normalizeCustomCell(e) {
        return { cellKind: "custom", url: e.static_url || e.url, shortcode: e.shortcode, ch: "", code: "" }
    }
    function normalizeUnicodeCell(hex) {
        return { cellKind: "unicode", url: AppLib.EmojiManager.unicodeImageUrl(hex),
            ch: AppLib.EmojiManager.codepointToChar(hex), code: hex, shortcode: "" }
    }
    function normalizeFlagCell(pair) {
        return { cellKind: "unicode", url: AppLib.EmojiManager.flagImageUrl(pair[0], pair[1]),
            ch: AppLib.EmojiManager.codepointToChar(pair[0]) + AppLib.EmojiManager.codepointToChar(pair[1]),
            code: pair[0] + "-" + pair[1], shortcode: "" }
    }
    function normalizeRecentCell(e) {
        return e.kind === "custom"
            ? { cellKind: "custom", url: e.url, shortcode: e.shortcode, ch: "", code: "" }
            : { cellKind: "unicode", url: e.url, ch: e.char, code: e.code || "", shortcode: "" }
    }

    function appendChunkedRows(category, items, normalizeFn) {
        var cols = emojiPickerDialog.gridColumns
        for (var i = 0; i < items.length; i += cols) {
            var cells = []
            for (var j = i; j < Math.min(i + cols, items.length); j++)
                cells.push(normalizeFn(items[j]))
            if (!(category in emojiPickerDialog.categoryIndex))
                emojiPickerDialog.categoryIndex[category] = rowsModel.count
            rowsModel.append({ category: category, cellsJson: JSON.stringify(cells) })
        }
    }

    //building rows per need is cheaper
    function rebuildRows() {
        rowsModel.clear()
        categoryIndex = {}

        var recent = emojiPickerDialog.recentEmojis.filter(function(e) {
            return e.kind === "custom"
                ? emojiPickerDialog.matchesQuery("", e.shortcode)
                : emojiPickerDialog.matchesQuery(EmojiCodepoints.nameForCode(e.code || ""), "")
        })
        appendChunkedRows(qsTr("Last used"), recent, normalizeRecentCell)

        var custom = emojiPickerDialog.customEmojis.filter(function(e) {
            return emojiPickerDialog.matchesQuery("", e.shortcode)
        })
        appendChunkedRows(qsTr("Custom"), custom, normalizeCustomCell)

        var groups = EmojiCodepoints.groupedCodepoints()
        for (var g = 0; g < groups.length; g++) {
            var filteredCodes = groups[g].codes.filter(function(hex) {
                return emojiPickerDialog.matchesQuery(EmojiCodepoints.emojiName(hex), "")
            })
            appendChunkedRows(groups[g].group, filteredCodes, normalizeUnicodeCell)
        }

        var flags = EmojiCodepoints.flagPairs().filter(function(pair) {
            return emojiPickerDialog.matchesQuery(EmojiCodepoints.flagName(pair[0], pair[1]), "")
        })
        appendChunkedRows(qsTr("Flags"), flags, normalizeFlagCell)

        pickerListView.positionViewAtBeginning()
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

    ListModel {
        id: rowsModel
    }


    Column {
        id: topBar
        width: parent.width
        spacing: Theme.paddingMedium

        DialogHeader {
            acceptText: qsTr("Insert")
        }

        SearchField {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            placeholderText: qsTr("Search emoji")
            onTextChanged: emojiPickerDialog.searchQuery = text.trim().toLowerCase()
        }

        Flow {
            id: categoryJumpBar
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            spacing: Theme.paddingSmall

            visible: emojiPickerDialog.searchQuery.length === 0

            Repeater {
                model: emojiPickerDialog.jumpTargets

                Item {
                    width: emojiPickerDialog.jumpCellSize
                    height: emojiPickerDialog.jumpCellSize
                    PanelBackground {
                        anchors.fill: parent
                        opacity: 0.5
                    }
                    Image {
                        anchors.centerIn: parent
                        source: modelData.iconSource.length > 0 ? modelData.iconSource : modelData.imageUrl
                        width:Theme.iconSizeMedium
                        height: width
                        asynchronous: true
                        sourceSize.width: width
                        sourceSize.height: height
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: emojiPickerDialog.scrollToCategory(modelData.category)
                    }

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
    }

    SilicaListView { //using ListView for virtualization
        id: pickerListView
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        model: rowsModel

        clip: true

        section.property: "category"
        section.delegate: SectionHeader {
            text: section
        }

        delegate: Row {
            id: rowDelegate
            x: Theme.horizontalPageMargin
            width: pickerListView.width - 2 * Theme.horizontalPageMargin
            height: emojiPickerDialog.cellSize

            readonly property var rowCells: JSON.parse(cellsJson)

            // Indexing into rowCells[] directly
            Repeater {
                model: rowDelegate.rowCells.length

                Item {
                    id: cellItem
                    width: emojiPickerDialog.cellSize
                    height: emojiPickerDialog.cellSize

                    readonly property var cell: rowDelegate.rowCells[index]
                    readonly property bool isCustom: cell.cellKind === "custom"
                    readonly property bool isSelected: isCustom
                        ? emojiPickerDialog.selectedShortcode === cell.shortcode
                        : emojiPickerDialog.selectedChar === cell.ch

                    Loader {
                        anchors.fill: parent
                        active: cellItem.isSelected
                        sourceComponent: cellHighlight
                    }

                    Image {
                        anchors.centerIn: parent
                        width: Theme.iconSizeMedium
                        height: width
                        source: cellItem.cell.url
                        asynchronous: true
                        sourceSize.width: width
                        sourceSize.height: height
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (cellItem.isCustom)
                                emojiPickerDialog.selectShortcode(cellItem.cell.shortcode, cellItem.cell.url)
                            else
                                emojiPickerDialog.selectChar(cellItem.cell.ch, cellItem.cell.url, cellItem.cell.code)
                        }
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
