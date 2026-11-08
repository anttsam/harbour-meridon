.pragma library
.import "HttpClient.js" as HttpClient

// Read-only access to a Lemmy server's public API (v3, what 0.19 serves).
// Like PeerTube.js, a Lemmy post can't be shown properly through Mastodon: it
// arrives as a status holding the title and a link, without the post's body,
// score or comment tree. LemmyPage.qml shows it from the server's own API.
//
// Lemmy post ids are only meaningful on the server they were read from, so
// every call takes the host the link pointed at.

// /post/<id> and /comment/<id>. PieFed, Pixelfed and others use similar
// paths, hence callers confirm with fetchPost() before committing to a page.
var linkRe = /^https?:\/\/([^\/?#]+)\/(post|comment)\/(\d+)(?:[\/?#]|$)/i

function parseUrl(url) {
    var match = linkRe.exec(url || "")
    return match ? { host: match[1], kind: match[2].toLowerCase(), id: match[3] } : null
}

function get(host, path, onSuccess, onFailure) {
    HttpClient.request("GET", "https://" + host + "/api/v3" + path, null, null, function (json) {
        if (json)
            onSuccess(json)
        else
            onFailure(0, "Invalid response")
    }, onFailure, "[Lemmy]")
}

// onSuccess(postView): {post, creator, community, counts, ...}
function fetchPost(host, postId, onSuccess, onFailure) {
    get(host, "/post?id=" + encodeURIComponent(postId), function (json) {
        if (json.post_view && json.post_view.post)
            onSuccess(json.post_view)
        else
            onFailure(0, "Not a Lemmy post")
    }, onFailure)
}

// A link may point at a comment, in which case the page shows its post
function resolveLink(link, onSuccess, onFailure) {
    if (link.kind === "post") {
        fetchPost(link.host, link.id, onSuccess, onFailure)
        return
    }
    get(link.host, "/comment?id=" + encodeURIComponent(link.id), function (json) {
        if (json.comment_view && json.comment_view.comment)
            fetchPost(link.host, json.comment_view.comment.post_id, onSuccess, onFailure)
        else
            onFailure(0, "Not a Lemmy comment")
    }, onFailure)
}

// sort: Hot | Top | New | Old. With max_depth the server ignores limit and
// page and returns the whole tree down to that depth in one go, capped at 300
// comments, which is plenty for a phone and saves paging.
function fetchComments(host, postId, sort, onSuccess, onFailure) {
    get(host, "/comment/list?post_id=" + encodeURIComponent(postId) + "&sort=" + sort
        + "&type_=All&max_depth=8", function (json) {
        onSuccess(json.comments || [])
    }, onFailure)
}

function handleOf(actor) {
    if (!actor)
        return ""
    var match = /^https?:\/\/([^\/]+)\/(?:u|c)\/([^\/?#]+)/.exec(actor.actor_id || "")
    return match ? actor.name + "@" + match[1] : (actor.name || "")
}

function mapComment(view, depth, markdownToHtml, host) {
    var comment = view.comment
    var gone = comment.deleted || comment.removed
    return {
        commentId: comment.id,
        depth: depth,
        html: gone ? "" : markdownToHtml(comment.content, host),
        isDeleted: gone,
        authorName: view.creator.display_name || view.creator.name || "",
        authorHandle: handleOf(view.creator),
        avatarUrl: view.creator.avatar || "",
        createdAt: comment.published || "",
        score: view.counts ? view.counts.score : 0,
        totalReplies: 0,
        repliesLoaded: false,
        repliesBusy: false
    }
}

// The API's flat list to display rows in tree order. A comment's path is
// "0.<ancestor ids>.<own id>"; siblings keep the order the server sent them
// in (its sort). A comment whose parent was not loaded (a later page, or cut
// off by max_depth) is shown as a root rather than dropped.
function buildRows(views, markdownToHtml, host) {
    var byId = {}
    var children = {}
    var i
    for (i = 0; i < views.length; i++)
        byId[views[i].comment.id] = views[i]

    var roots = []
    for (i = 0; i < views.length; i++) {
        var ids = views[i].comment.path.split(".")
        var parent = ids.length >= 3 ? ids[ids.length - 2] : "0"
        if (parent !== "0" && byId[parent]) {
            if (!children[parent])
                children[parent] = []
            children[parent].push(views[i])
        } else {
            roots.push(views[i])
        }
    }

    var rows = []
    function walk(view, depth) {
        var at = rows.length
        rows.push(mapComment(view, depth, markdownToHtml, host))
        var kids = children[view.comment.id] || []
        for (var k = 0; k < kids.length; k++)
            walk(kids[k], depth + 1)
        // everything below it, so the row can say how many replies it hides
        rows[at].totalReplies = rows.length - at - 1
    }
    for (i = 0; i < roots.length; i++)
        walk(roots[i], 0)
    return rows
}
