.pragma library
.import "LocalDb.js" as LocalDb

function getDatabase() {
    return LocalDb.openDb("MeridonPreferences", "App preferences")
}

function ensureTable(tx) {
    LocalDb.ensureTables(tx, [
        "CREATE TABLE IF NOT EXISTS preferences (key TEXT UNIQUE, value TEXT)"
    ])
}

function saveFontChoice(key) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)",
            ["fontChoice", key])
    })
}

// Returns "" if nothing has been saved yet.
function loadFontChoice() {
    var db = getDatabase()
    var result = ""

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT value FROM preferences WHERE key = ?", ["fontChoice"])
        if (rs.rows.length > 0)
            result = rs.rows.item(0).value
    })

    return result
}

function saveFontSizeMultiplier(value) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)",
            ["fontSizeMultiplier", String(value)])
    })
}

// Returns 0 if nothing has been saved yet (caller decides the default).
function loadFontSizeMultiplier() {
    var db = getDatabase()
    var result = 0

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT value FROM preferences WHERE key = ?", ["fontSizeMultiplier"])
        if (rs.rows.length > 0)
            result = parseFloat(rs.rows.item(0).value) || 0
    })

    return result
}

function saveLineHeightMultiplier(value) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)",
            ["lineHeightMultiplier", String(value)])
    })
}

// Returns 0 if nothing has been saved yet (caller decides the default).
function loadLineHeightMultiplier() {
    var db = getDatabase()
    var result = 0

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT value FROM preferences WHERE key = ?", ["lineHeightMultiplier"])
        if (rs.rows.length > 0)
            result = parseFloat(rs.rows.item(0).value) || 0
    })

    return result
}

function saveLightWeight(enabled) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)",
            ["lightWeight", enabled ? "1" : "0"])
    })
}

// Returns "" if nothing has been saved yet (caller decides the default).
function loadLightWeight() {
    var db = getDatabase()
    var result = ""

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT value FROM preferences WHERE key = ?", ["lightWeight"])
        if (rs.rows.length > 0)
            result = rs.rows.item(0).value
    })

    return result
}

function saveBackgroundOpacity(value) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)",
            ["backgroundOpacity", String(value)])
    })
}

// Returns "" if nothing has been saved yet - unlike the multipliers above,
// 0 is a legitimate real value here (fully transparent), so it can't
// double as the "nothing saved" sentinel the way it does for those.
function loadBackgroundOpacity() {
    var db = getDatabase()
    var result = ""

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT value FROM preferences WHERE key = ?", ["backgroundOpacity"])
        if (rs.rows.length > 0)
            result = rs.rows.item(0).value
    })

    return result
}

function saveBackgroundColorKey(key) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)",
            ["backgroundColorKey", key])
    })
}

// Returns "" if nothing has been saved yet.
function loadBackgroundColorKey() {
    var db = getDatabase()
    var result = ""

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT value FROM preferences WHERE key = ?", ["backgroundColorKey"])
        if (rs.rows.length > 0)
            result = rs.rows.item(0).value
    })

    return result
}

function saveHighlightKey(key) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)",
            ["highlightKey", key])
    })
}

// Returns "" if nothing has been saved yet.
function loadHighlightKey() {
    var db = getDatabase()
    var result = ""

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT value FROM preferences WHERE key = ?", ["highlightKey"])
        if (rs.rows.length > 0)
            result = rs.rows.item(0).value
    })

    return result
}

function saveAffectCover(enabled) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)",
            ["affectCover", enabled ? "1" : "0"])
    })
}

// Returns "" if nothing has been saved yet.
function loadAffectCover() {
    var db = getDatabase()
    var result = ""

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT value FROM preferences WHERE key = ?", ["affectCover"])
        if (rs.rows.length > 0)
            result = rs.rows.item(0).value
    })

    return result
}

function saveRenderEmojis(enabled) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)",
            ["renderEmojis", enabled ? "1" : "0"])
    })
}

// Returns "" if nothing has been saved yet.
function loadRenderEmojis() {
    var db = getDatabase()
    var result = ""

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT value FROM preferences WHERE key = ?", ["renderEmojis"])
        if (rs.rows.length > 0)
            result = rs.rows.item(0).value
    })

    return result
}

function saveAffectTabBar(enabled) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)",
            ["affectTabBar", enabled ? "1" : "0"])
    })
}

// Returns "" if nothing has been saved yet.
function loadAffectTabBar() {
    var db = getDatabase()
    var result = ""

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT value FROM preferences WHERE key = ?", ["affectTabBar"])
        if (rs.rows.length > 0)
            result = rs.rows.item(0).value
    })

    return result
}

function saveAutoplayGifs(enabled) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)",
            ["autoplayGifs", enabled ? "1" : "0"])
    })
}

// Returns "" if nothing has been saved yet.
function loadAutoplayGifs() {
    var db = getDatabase()
    var result = ""

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT value FROM preferences WHERE key = ?", ["autoplayGifs"])
        if (rs.rows.length > 0)
            result = rs.rows.item(0).value
    })

    return result
}
