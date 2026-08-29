.pragma library
.import "LocalDb.js" as LocalDb

// Caches the OAuth app registration (client_id/client_secret) Mastodon's
// POST /api/v1/apps returns per instance, keyed by instance domain (e.g.
// "mastodon.social") - so logging into an instance a second time (or
// re-logging-in after a logout) skips re-registering an app with it.
// Separate table/module from TokenStorage.js because this data outlives
// any one user's session on that instance and isn't cleared on logout.

function getDatabase() {
    return LocalDb.openDb("MastodonInstanceApps", "Per-instance OAuth app registrations")
}

function ensureTable(tx) {
    LocalDb.ensureTables(tx, [
        "CREATE TABLE IF NOT EXISTS instance_apps (domain TEXT UNIQUE, clientId TEXT, clientSecret TEXT)"
    ])
}

function saveApp(domain, clientId, clientSecret) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql(
            "INSERT OR REPLACE INTO instance_apps (domain, clientId, clientSecret) VALUES (?, ?, ?)",
            [domain, clientId, clientSecret])
    })
}

// Returns { clientId, clientSecret } or null if this instance hasn't been
// registered with yet.
function loadApp(domain) {
    var db = getDatabase()
    var result = null

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql(
            "SELECT clientId, clientSecret FROM instance_apps WHERE domain = ?", [domain])
        if (rs.rows.length > 0) {
            result = {
                clientId: rs.rows.item(0).clientId,
                clientSecret: rs.rows.item(0).clientSecret
            }
        }
    })

    return result
}
