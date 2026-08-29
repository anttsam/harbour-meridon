.pragma library
.import "LocalDb.js" as LocalDb

// Persists the "Last used" row in EmojiPickerDialog.qml - an ordered list
// (most recent first) of up to 24 entries, stored as one JSON blob rather
// than a row-per-entry table, since the whole list is always read/written
// together and reordering-in-place on every pick is simpler as an array
// operation than a series of SQL statements.

var MAX_ENTRIES = 24

function getDatabase() {
    return LocalDb.openDb("MeridonEmojiRecent", "Recently used emoji")
}

function ensureTable(tx) {
    LocalDb.ensureTables(tx, [
        "CREATE TABLE IF NOT EXISTS recent (key TEXT UNIQUE, value TEXT)"
    ])
}

// Returns [] if nothing has been picked yet. Each entry is either
// {kind: "custom", shortcode, url} or {kind: "unicode", char, url} -
// enough to both render the cell and reselect it without needing to
// re-derive anything from EmojiCodepoints.js or a fresh custom_emojis
// fetch.
function loadRecent() {
    var db = getDatabase()
    var result = []

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT value FROM recent WHERE key = ?", ["list"])
        if (rs.rows.length > 0) {
            try {
                result = JSON.parse(rs.rows.item(0).value) || []
            } catch (e) {
                result = []
            }
        }
    })

    return result
}

function saveRecent(list) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO recent (key, value) VALUES (?, ?)",
            ["list", JSON.stringify(list)])
    })
}

// Moves entry to the front if already present (rather than duplicating),
// otherwise inserts it there, capped at MAX_ENTRIES. Identity is by
// shortcode for custom emoji, by char for Unicode ones - two entries with
// the same identity are the same emoji even if other fields differ.
function recordUsed(entry) {
    var list = loadRecent()

    var isSame = function(a, b) {
        if (a.kind !== b.kind)
            return false
        return a.kind === "custom" ? a.shortcode === b.shortcode : a.char === b.char
    }

    var filtered = list.filter(function(existing) {
        return !isSame(existing, entry)
    })

    filtered.unshift(entry)
    saveRecent(filtered.slice(0, MAX_ENTRIES))
}
