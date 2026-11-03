.pragma library
.import "HttpClient.js" as HttpClient

// Read-only access to a PeerTube instance's public REST API. Unlike the
// Mastodon calls in SessionManager.js these go straight to the host that
// serves the video (taken from the link or card), unauthenticated.
//
// Mastodon can't represent a PeerTube Video: search+resolve turns it into a
// status holding only the title and a link, with no stream and none of the
// video's comments. So a PeerTube link is recognised by its URL shape (or by
// the oEmbed iframe in the preview card, see PostMapper.js) and shown by
// PeerTubePage.qml from this API instead.

// PeerTube ids are a UUID, a 22 character base58 shortUUID or a numeric id
var watchRe = /^https?:\/\/([^\/?#]+)\/(?:w|videos\/watch|videos\/embed)\/([A-Za-z0-9-]{8,40})(?:[\/?#]|$)/i

// Returns {host, id} for a PeerTube video URL, else null. Only the shape is
// checked here - other sites use /w/ too, so callers that can't tolerate a
// false positive must confirm with fetchVideo().
function parseVideoUrl(url) {
    var match = watchRe.exec(url || "")
    return match ? { host: match[1], id: match[2] } : null
}

function apiUrl(host, path) {
    return "https://" + host + "/api/v1" + path
}

function absoluteUrl(host, path) {
    if (!path)
        return ""
    return /^https?:\/\//i.test(path) ? path : "https://" + host + path
}

function get(host, path, onSuccess, onFailure) {
    HttpClient.request("GET", apiUrl(host, path), null, null, function (json) {
        if (json)
            onSuccess(json)
        else
            onFailure(0, "Invalid response")
    }, onFailure, "[PeerTube]")
}

function fetchVideo(host, id, onSuccess, onFailure) {
    get(host, "/videos/" + encodeURIComponent(id), onSuccess, onFailure)
}

// The video endpoint only carries a shortened description
function fetchDescription(host, id, onSuccess) {
    get(host, "/videos/" + encodeURIComponent(id) + "/description", function (json) {
        onSuccess(json.description || "")
    }, function () {})
}

// sort: "-createdAt" (newest first) or "createdAt"
function fetchThreads(host, id, start, count, sort, onSuccess, onFailure) {
    get(host, "/videos/" + encodeURIComponent(id) + "/comment-threads?start=" + start
        + "&count=" + count + "&sort=" + sort, onSuccess, onFailure)
}

function fetchThread(host, id, threadId, onSuccess, onFailure) {
    get(host, "/videos/" + encodeURIComponent(id) + "/comment-threads/" + threadId,
        onSuccess, onFailure)
}

// Best stream for MediaPlayer, or "". A plain MP4 is preferred over HLS: the
// device's GStreamer plays MP4 reliably, HLS from PeerTube is fragmented MP4
// and untested. 720p at most, mobile data and screen size don't need more.
function pickStreamUrl(video) {
    function best(files) {
        var chosen = null
        for (var i = 0; i < (files || []).length; i++) {
            var f = files[i]
            // resolution 0 is an audio only file
            if (!f.fileUrl || !f.resolution || f.resolution.id === 0)
                continue
            var res = f.resolution.id
            var chosenRes = chosen ? chosen.resolution.id : -1
            // closest to 720 from below, else the smallest above it
            var better = !chosen
                || (res <= 720 && (chosenRes > 720 || res > chosenRes))
                || (res > 720 && chosenRes > 720 && res < chosenRes)
            if (better)
                chosen = f
        }
        return chosen ? chosen.fileUrl : ""
    }

    var url = best(video.files)
    if (url.length > 0)
        return url

    var playlists = video.streamingPlaylists || []
    for (var p = 0; p < playlists.length; p++)
        if (playlists[p].playlistUrl)
            return playlists[p].playlistUrl
    return ""
}

// Smallest avatar that is still sharp at roughly 64px
function avatarUrl(host, actor) {
    if (!actor)
        return ""
    var list = actor.avatars || (actor.avatar ? [actor.avatar] : [])
    var chosen = null
    for (var i = 0; i < list.length; i++) {
        var a = list[i]
        if (!chosen || (chosen.width < 64 && a.width > chosen.width)
                || (a.width >= 64 && a.width < chosen.width))
            chosen = a
    }
    return chosen ? absoluteUrl(host, chosen.fileUrl || chosen.path) : ""
}

function escapeHtml(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// Local comments arrive as plain text, federated ones as HTML
function commentHtml(text) {
    text = text || ""
    if (/<[a-z][^>]*>/i.test(text))
        return text
    return escapeHtml(text).replace(/\n/g, "<br>")
}

// Flat row for the comment ListModel. Only scalar roles, see the ListModel
// notes in the Qt 5.6 quirks.
function mapComment(host, comment, depth) {
    var account = comment.account || {}
    var handle = account.name ? "@" + account.name + (account.host ? "@" + account.host : "") : ""
    return {
        commentId: comment.id,
        threadId: comment.threadId,
        depth: depth,
        html: comment.isDeleted ? "" : commentHtml(comment.text),
        isDeleted: !!comment.isDeleted,
        authorName: account.displayName || account.name || "",
        authorHandle: handle,
        avatarUrl: avatarUrl(host, account),
        createdAt: comment.createdAt || "",
        totalReplies: comment.totalReplies || 0,
        repliesLoaded: false,
        repliesBusy: false
    }
}

// Nested {comment, children} tree to depth-first rows. Depth is kept as is,
// the delegate caps the indentation.
function flattenReplies(host, children, depth, rows) {
    rows = rows || []
    for (var i = 0; i < (children || []).length; i++) {
        rows.push(mapComment(host, children[i].comment, depth))
        flattenReplies(host, children[i].children, depth + 1, rows)
    }
    return rows
}
