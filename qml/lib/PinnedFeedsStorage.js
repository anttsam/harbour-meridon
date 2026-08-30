.pragma library
.import "LocalDb.js" as LocalDb

// Local source of truth for the non-list feeds pinned to the Home
// carousel (currently just Home itself - Local/Federated timeline
// toggles would extend this same table later). Mastodon has no
// server-side equivalent to AT Proto's savedFeedsPrefV2 preference, so
// unlike the old FeedsManager.js (which fetched this fresh from the
// server every session), it has to live somewhere locally. Same
// QtQuick.LocalStorage key/value-table pattern as TokenStorage.js.
//
// Lists are handled separately, below - they show up in the carousel
// automatically (FeedsManager.loadFeeds() merges in every list from
// GET /api/v1/lists on its own), so all this file tracks for them is the
// opt-out: which ones the user explicitly dismissed.

function getDatabase() {
    return LocalDb.openDb("MastodonPinnedFeeds", "Locally pinned feeds/lists")
}

function ensureTable(tx) {
    LocalDb.ensureTables(tx, [
        "CREATE TABLE IF NOT EXISTS pinned_feeds "
        + "(id TEXT UNIQUE, type TEXT, value TEXT, displayName TEXT, pinned INTEGER, sortOrder INTEGER)",
        "CREATE TABLE IF NOT EXISTS dismissed_lists (listId TEXT UNIQUE)",
        "CREATE TABLE IF NOT EXISTS dismissed_hashtags (hashtagName TEXT UNIQUE)"
    ])
}

// Lists are shown in the Home carousel automatically (see
// FeedsManager.loadFeeds(), which merges in every list from GET
// /api/v1/lists on its own) - this table is just the opt-out: list ids
// the user explicitly removed via ListManagePage.qml, so a fresh
// GET /api/v1/lists response doesn't bring them right back.
function getDismissedListIds() {
    var db = getDatabase()
    var ids = {}
    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT listId FROM dismissed_lists")
        for (var i = 0; i < rs.rows.length; i++)
            ids[rs.rows.item(i).listId] = true
    })
    return ids
}

function dismissList(listId) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql("INSERT OR REPLACE INTO dismissed_lists (listId) VALUES (?)", [listId])
    })
}

function undismissList(listId) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql("DELETE FROM dismissed_lists WHERE listId = ?", [listId])
    })
}

// Same idea as the dismissed-lists table above, for followed hashtags -
// unlike a list (server has no "hide from carousel" concept), a hashtag
// can't be dismissed by unfollowing it without also losing the follow
// itself, so this is a genuinely separate opt-out.
function getDismissedHashtagIds() {
    var db = getDatabase()
    var ids = {}
    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql("SELECT hashtagName FROM dismissed_hashtags")
        for (var i = 0; i < rs.rows.length; i++)
            ids[rs.rows.item(i).hashtagName] = true
    })
    return ids
}

function dismissHashtag(name) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql("INSERT OR REPLACE INTO dismissed_hashtags (hashtagName) VALUES (?)", [name])
    })
}

function undismissHashtag(name) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql("DELETE FROM dismissed_hashtags WHERE hashtagName = ?", [name])
    })
}

function defaultHomeFeed() {
    // Mastodon's own endpoint/type is "home" (GET /api/v1/timelines/home)
    // and that's what stays as the internal type discriminator - but the
    // official iOS app itself now labels this tab "Following", and
    // Meridon follows that convention for the user-facing name.
    return { id: "home", type: "home", value: "", pinned: true, displayName: "Following" }
}

// Returns the ordered list of locally-pinned feeds/lists, seeding the
// default Home timeline the very first time this is called (nothing
// stored yet - e.g. right after a fresh login).
function loadFeeds() {
    var db = getDatabase()
    var result = []

    db.transaction(function(tx) {
        ensureTable(tx)
        var rs = tx.executeSql(
            "SELECT id, type, value, displayName, pinned FROM pinned_feeds ORDER BY sortOrder ASC")
        for (var i = 0; i < rs.rows.length; i++) {
            var row = rs.rows.item(i)
            result.push({
                id: row.id,
                type: row.type,
                value: row.value,
                // The "home" row's name isn't user-editable, unlike a
                // list/hashtag's - always use the current canonical
                // label rather than trusting whatever's stored, so an
                // install that already persisted this row under an
                // older label (e.g. before this was renamed from "Home"
                // to "Following") picks up the rename without needing
                // an explicit migration.
                displayName: row.type === "home" ? defaultHomeFeed().displayName : row.displayName,
                pinned: row.pinned === 1
            })
        }
    })

    if (result.length === 0) {
        var seed = defaultHomeFeed()
        saveFeeds([seed])
        return [seed]
    }

    return result
}

// Replaces the entire stored feed list with the given ordered array of
// {id, type, value, pinned, displayName} - simplest persistence model
// given the whole list is always held and mutated as one in-memory array
// anyway (mirrors how FeedsManager.js's own feeds[] is built/reordered).
function saveFeeds(list) {
    var db = getDatabase()
    db.transaction(function(tx) {
        ensureTable(tx)
        tx.executeSql("DELETE FROM pinned_feeds")
        for (var i = 0; i < list.length; i++) {
            var f = list[i]
            tx.executeSql(
                "INSERT INTO pinned_feeds (id, type, value, displayName, pinned, sortOrder) VALUES (?, ?, ?, ?, ?, ?)",
                [f.id, f.type, f.value, f.displayName || "", f.pinned ? 1 : 0, i])
        }
    })
}
