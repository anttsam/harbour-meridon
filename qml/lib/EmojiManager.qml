pragma Singleton
import QtQuick 2.0
import "FontPreferenceStorage.js" as FontPreferenceStorage
import "EmojiCodepoints.js" as EmojiCodepoints

// Renders emoji as colorful inline images in post text and display names,
// gated by "Render colorful emojis" Settings switch. Two independent
// sources feed the same render() pass:
// 1. Mastodon's per-server custom emoji
// 2. Standard Unicode emoji (😀 etc.)
// Substitution happens here at render time mostly

QtObject {
    id: emojiManager

    property bool renderEmojis: true

    function selectRenderEmojis(enabled) {
        emojiManager.renderEmojis = enabled
        FontPreferenceStorage.saveRenderEmojis(enabled)
    }

    // this height seems to  keep the rowheigh, no idea why
    readonly property real _emojiSizeRatio: 1.23

    property var _unicodeMap: null
    property var _unicodeRegex: null

    // This engine doesn't have String.fromCodePoint (ES2015) - build the
    // UTF-16 surrogate pair by hand for astral codepoints (everything
    // above the Basic Multilingual Plane, i.e. most emoji, U+10000+).
    function _charFromCodePoint(cp) {
        if (cp <= 0xFFFF)
            return String.fromCharCode(cp)

        cp -= 0x10000
        return String.fromCharCode(0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF))
    }

    function _ensureUnicodeMap() {
        if (emojiManager._unicodeMap !== null)
            return

        var codes = EmojiCodepoints.codepoints()
        var map = {}
        var escaped = []
        for (var i = 0; i < codes.length; i++) {
            var hex = codes[i]
            var ch = emojiManager._charFromCodePoint(parseInt(hex, 16))
            map[ch] = Qt.resolvedUrl("emoji/" + hex + ".png")
            escaped.push(ch.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
        }

        // Country/region flags
        var flagPairs = EmojiCodepoints.flagPairs()
        for (var j = 0; j < flagPairs.length; j++) {
            var pair = flagPairs[j]
            var flagCh = emojiManager._charFromCodePoint(parseInt(pair[0], 16))
                + emojiManager._charFromCodePoint(parseInt(pair[1], 16))
            map[flagCh] = Qt.resolvedUrl("flags/" + pair[0] + "-" + pair[1] + ".png")
            escaped.push(flagCh.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
        }

        emojiManager._unicodeMap = map
        // Built once and reused
        emojiManager._unicodeRegex = new RegExp(escaped.join("|"), "g")
    }

    function _imgTag(url, size) {
        return '<img src="' + url + '" width="' + size + '" height="' + size + '" align="bottom">'
    }

    // Public helpers
    function unicodeImageUrl(hex) {
        return Qt.resolvedUrl("emoji/" + hex + ".png")
    }

    function flagImageUrl(hexA, hexB) {
        return Qt.resolvedUrl("flags/" + hexA + "-" + hexB + ".png")
    }

    function codepointToChar(hex) {
        return emojiManager._charFromCodePoint(parseInt(hex, 16))
    }

    // animated emojis are not supporte
    function render(text, emojisJson, fontPixelSize) {
        if (!emojiManager.renderEmojis || !text)
            return text

        var size = Math.round((fontPixelSize || 20) * emojiManager._emojiSizeRatio)
        var result = text

        if (emojisJson && emojisJson !== "{}") {
            var shortcodeMap
            try {
                shortcodeMap = JSON.parse(emojisJson)
            } catch (e) {
                shortcodeMap = null
            }
            if (shortcodeMap) {
                result = result.replace(/:([a-zA-Z0-9_]+):/g, function(match, shortcode) {
                    var url = shortcodeMap[shortcode]
                    return url ? emojiManager._imgTag(url, size) : match
                })
            }
        }

        emojiManager._ensureUnicodeMap()
        result = result.replace(emojiManager._unicodeRegex, function(match) {
            var url = emojiManager._unicodeMap[match]
            return url ? emojiManager._imgTag(url, size) : match
        })

        return result
    }

    Component.onCompleted: {
        var saved = FontPreferenceStorage.loadRenderEmojis()
        if (saved !== "")
            emojiManager.renderEmojis = saved === "1"
    }
}
