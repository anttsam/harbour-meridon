.pragma library
.import "LocalDb.js" as LocalDb

function getDatabase() {
    return LocalDb.openDb("MastodonSession", "Session token storage")
}

function ensureTable(tx) {
    LocalDb.ensureTables(tx, [
        "CREATE TABLE IF NOT EXISTS session (key TEXT UNIQUE, value TEXT)"
    ])
}

// Note: this is plain-text storage in a local SQLite file under the app's
// private data directory - not encrypted. Fine for getting persistence
// working, but for a real release build consider migrating to
// Sailfish.Secrets, which stores values in the system's encrypted
// secrets vault instead of an app-local database file.

function saveSession(accessToken, instanceUrl, accountId, username) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        var values = {
            accessToken: accessToken,
            instanceUrl: instanceUrl,
            accountId: accountId,
            username: username
        }
        for (var key in values) {
            tx.executeSql(
                "INSERT OR REPLACE INTO session (key, value) VALUES (?, ?)",
                [key, values[key]])
        }
    })
}

// Returns { accessToken, instanceUrl, accountId, username } or null if
// nothing stored.
function loadSession() {
    var db = getDatabase()
    var result = null

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT key, value FROM session")
        if (rs.rows.length > 0) {
            result = {}
            for (var i = 0; i < rs.rows.length; i++) {
                var row = rs.rows.item(i)
                result[row.key] = row.value
            }
        }
    })

    // Guard against a partially-written session (shouldn't normally
    // happen, but better to force a fresh login than pass around
    // incomplete/undefined tokens).
    if (result && (!result.accessToken || !result.instanceUrl)) {
        return null
    }

    return result
}

function clearSession() {
    var db = getDatabase()
    db.transaction(function(tx) {
        tx.executeSql("DROP TABLE IF EXISTS session")
    })
}
