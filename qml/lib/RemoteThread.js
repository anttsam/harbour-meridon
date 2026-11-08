.pragma library
.import "HttpClient.js" as HttpClient

// A post from another server is shown with the replies the home server has
// received so far, which for a busy thread is often a fraction of it. The
// origin server knows the whole thread, and its public API needs no login, so
// this fetches /context from there and merges in the replies the home server
// is missing.
//
// Origin ids mean nothing on the home server, so a reply copied over is
// display only: its id and account id are blanked and PostDelegate.qml
// resolves it through search (by URL) when it is tapped.

// Servers that answer Mastodon's API with an error, so asking is pointless.
// Threads federates but has no such API; others are added when a request to
// them fails with an HTTP error, until the app is closed.
var unsupportedHosts = { "threads.net": true }

function isSupported(host) {
    return unsupportedHosts[host] !== true
}

// A transport error (offline, timeout) says nothing about the server
function noteFailure(host, status, message) {
    if (status !== 0 || message !== "Network error")
        unsupportedHosts[host] = true
}

function hostOf(url) {
    var match = /^https?:\/\/([^\/?#]+)/i.exec(url || "")
    return match ? match[1] : ""
}

function lastSegment(url) {
    var match = /\/([A-Za-z0-9_-]+)\/?(?:[?#].*)?$/.exec(url || "")
    return match ? match[1] : ""
}

function get(host, path, onSuccess, onFailure) {
    HttpClient.request("GET", "https://" + host + path, null, null, function (json) {
        if (json)
            onSuccess(json)
        else
            onFailure(0, "Invalid response")
    }, onFailure, "[RemoteThread]")
}

// focus: the home server's copy of the status. The id it has on its origin
// server isn't in the entity, so the usual places for it (the last part of
// url, then of uri) are tried and the answer is only trusted when it comes
// back with the same uri. Servers with other id schemes simply fail, which
// leaves the thread as it was.
// onSuccess({host, focusId, descendants}); onFailure(status, message)
function fetchContext(focus, onSuccess, onFailure) {
    var host = hostOf(focus.uri)
    if (host.length === 0) {
        onFailure(0, "No origin server")
        return
    }

    var candidates = []
    var guesses = [lastSegment(focus.url), lastSegment(focus.uri)]
    for (var i = 0; i < guesses.length; i++)
        if (guesses[i].length > 0 && candidates.indexOf(guesses[i]) < 0)
            candidates.push(guesses[i])

    function attempt(index, lastError) {
        if (index >= candidates.length) {
            onFailure(lastError.status, lastError.message)
            return
        }
        get(host, "/api/v1/statuses/" + encodeURIComponent(candidates[index]), function (status) {
            if (status.uri !== focus.uri) {
                attempt(index + 1, { status: 0, message: "Different post" })
                return
            }
            get(host, "/api/v1/statuses/" + encodeURIComponent(status.id) + "/context", function (context) {
                onSuccess({ host: host, focusId: status.id, descendants: context.descendants || [] })
            }, onFailure)
        }, function (status, message) {
            attempt(index + 1, { status: status, message: message })
        })
    }
    attempt(0, { status: 0, message: "Not found" })
}

// A status from the origin server, reshaped so PostMapper.mapStatus() can
// show it and nothing in it can act on the wrong object on the home server
function toLocalShape(status, host, parentId) {
    var copy = JSON.parse(JSON.stringify(status))
    copy.id = "remote:" + status.id
    copy.in_reply_to_id = parentId
    copy._remote = true

    // acct is relative to the server that sent it
    if (copy.account.acct.indexOf("@") < 0)
        copy.account.acct += "@" + host
    copy.account.id = ""

    // Ids in these point at the origin server's objects. Without mentions a
    // @name link falls back to LinkHandler's resolve by URL, which is right.
    copy.mentions = []
    copy.in_reply_to_account_id = null
    copy.poll = null
    copy.quote = null
    copy.favourited = false
    copy.reblogged = false
    copy.bookmarked = false
    return copy
}

// Returns {descendants, added}: the home server's descendants plus the origin
// ones it lacks, linked into the same tree. Matching is by uri (the
// ActivityPub id), the only id both servers share.
function merge(focus, localDescendants, origin) {
    var localIdByUri = {}
    localIdByUri[focus.uri] = focus.id
    for (var l = 0; l < localDescendants.length; l++)
        localIdByUri[localDescendants[l].uri] = localDescendants[l].id

    var originUriById = {}
    originUriById[origin.focusId] = focus.uri
    for (var o = 0; o < origin.descendants.length; o++)
        originUriById[origin.descendants[o].id] = origin.descendants[o].uri

    var merged = localDescendants.slice()
    var added = 0
    for (var i = 0; i < origin.descendants.length; i++) {
        var status = origin.descendants[i]
        if (localIdByUri[status.uri] !== undefined)
            continue

        // The parent is either something the home server has, or another
        // copied reply (which gets the same "remote:" id below)
        var parentLocalId = localIdByUri[originUriById[status.in_reply_to_id]]
        var parentId = parentLocalId !== undefined ? parentLocalId : "remote:" + status.in_reply_to_id
        merged.push(toLocalShape(status, origin.host, parentId))
        added++
    }
    return { descendants: merged, added: added }
}
