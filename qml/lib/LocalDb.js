.pragma library
.import QtQuick.LocalStorage 2.0 as LS

// Shared boilerplate for the app's local SQLite stores (TokenStorage.js,
// InstanceAppStorage.js, PinnedFeedsStorage.js) - each still opens its own
// separate named database, this just removes the copy-pasted
// openDatabaseSync()/CREATE TABLE IF NOT EXISTS shape.

function openDb(name, description, version, size) {
    return LS.LocalStorage.openDatabaseSync(
        name, version || "1.0", description, size || 100000)
}

// statements: array of either a raw SQL string, or [sql, params]
function ensureTables(tx, statements) {
    for (var i = 0; i < statements.length; i++) {
        var s = statements[i]
        if (Array.isArray(s))
            tx.executeSql(s[0], s[1])
        else
            tx.executeSql(s)
    }
}
