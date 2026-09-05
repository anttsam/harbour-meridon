.pragma library
.import "LocalDb.js" as LocalDb

// Separate database from PreferenceStorage.js's single key/value table -
// each preset is itself a named bundle of values, not a single scalar, so
// it gets its own name-keyed table instead. Only ever holds rows for the
// four fixed preset names (Native/More contrast/Mastodon/Custom) -
// see PresetManager.qml's own comment for the overall model.

function getDatabase() {
    return LocalDb.openDb("MeridonPresets", "Saved appearance presets")
}

function ensureTables(tx) {
    LocalDb.ensureTables(tx, [
        "CREATE TABLE IF NOT EXISTS presets (name TEXT UNIQUE, valuesJson TEXT)",
        "CREATE TABLE IF NOT EXISTS meta (key TEXT UNIQUE, value TEXT)"
    ])
}

// Persists a preset's "modified" snapshot - the live values last left in
// place while it was selected.
function savePreset(name, valuesJson) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTables(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO presets (name, valuesJson) VALUES (?, ?)",
            [name, valuesJson])
    })
}

// Returns "" if this preset has no saved modified snapshot yet (still at
// its own factory baseline).
function loadPreset(name) {
    var db = getDatabase()
    var result = ""

    db.transaction(function(tx) {
        ensureTables(tx)
        var rs = tx.executeSql("SELECT valuesJson FROM presets WHERE name = ?", [name])
        if (rs.rows.length > 0)
            result = rs.rows.item(0).valuesJson
    })

    return result
}

function saveSelectedPresetName(name) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTables(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)",
            ["selectedPreset", name])
    })
}

// Returns "" if nothing has been saved yet.
function loadSelectedPresetName() {
    var db = getDatabase()
    var result = ""

    db.transaction(function(tx) {
        ensureTables(tx)
        var rs = tx.executeSql("SELECT value FROM meta WHERE key = ?", ["selectedPreset"])
        if (rs.rows.length > 0)
            result = rs.rows.item(0).value
    })

    return result
}

// The Custom preset's own factory baseline - unlike the other three
// presets (hard-coded in PresetManager.qml), this one is itself
// user-settable via the "Save preset" pulldown action.
function saveCustomFactory(valuesJson) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTables(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)",
            ["customFactory", valuesJson])
    })
}

// Returns "" if never saved yet (PresetManager.qml falls back to Native's
// own factory values in that case).
function loadCustomFactory() {
    var db = getDatabase()
    var result = ""

    db.transaction(function(tx) {
        ensureTables(tx)
        var rs = tx.executeSql("SELECT value FROM meta WHERE key = ?", ["customFactory"])
        if (rs.rows.length > 0)
            result = rs.rows.item(0).value
    })

    return result
}
