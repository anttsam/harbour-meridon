.pragma library
.import "SessionManager.js" as SessionManager

// Routes a URL handed to this app by the OS (see src/urlrouter.cpp /
// harbour-meridon-open-url.desktop) to the right in-app page instead of
// falling back to Browser. There is no OS-level way to scope the https://
// claim to just fediverse links (Sailfish has nothing like iOS Universal
// Links/Android App Links) - Meridon is handed EVERY tapped https link,
// and has to decide for itself whether it's something it can show.
//
// Deliberately does NOT pre-filter by URL shape before asking the server -
// Mastodon's own search+resolve doesn't care what a URL looks like, it
// just fetches whatever ActivityPub object is at that URI, so it can
// resolve cross-platform fediverse content (Lemmy, Pixelfed, PeerTube,
// ...) that a Mastodon-permalink-shaped regex would never match. The
// trade-off: every https link tapped anywhere on the device (fediverse or
// not) costs one search API round-trip against the logged-in instance
// before falling back to Browser - accepted deliberately over silently
// missing links like a Lemmy post shared through a Mastodon toot.

var tagPathRe = /^\/tags\/([^\/?#]+)/i
var authorizeInteractionRe = /\/authorize_interaction\/?\?.*\buri=([^&]+)/i

function pathOf(url) {
    return url.replace(/^https?:\/\/[^\/]+/i, "")
}

// Mastodon's web UI redirects through .../authorize_interaction?uri=<url>
// when a tapped link points at content on a different instance than the
// one currently being browsed (e.g. sharing a mastodon.social link to a
// techhub.social post while logged out of techhub.social) - the actual
// target is URL-encoded in the uri= param, not the outer path shape.
function unwrapAuthorizeInteraction(url) {
    var match = authorizeInteractionRe.exec(url)
    if (!match)
        return url
    try {
        return decodeURIComponent(match[1])
    } catch (e) {
        return url
    }
}

// Exactly one of the four callbacks is invoked. Hashtags need no
// resolution (the tag name is already in the URL) and are checked first
// as a free fast path; everything else goes through Mastodon's own
// search+resolve against whichever account is currently logged in.
// onUnhandled covers not being logged in, or the resolve finding nothing -
// callers should hand the URL to Qt.openUrlExternally() there.
function resolveAndRoute(url, onStatus, onProfile, onHashtag, onUnhandled) {
    url = unwrapAuthorizeInteraction(url)

    if (!SessionManager.isLoggedIn()) {
        console.log("[UrlRouter] not logged in, unhandled:", url)
        onUnhandled()
        return
    }

    var tagMatch = tagPathRe.exec(pathOf(url))
    if (tagMatch) {
        onHashtag(decodeURIComponent(tagMatch[1]))
        return
    }

    var searchPath = "/api/v2/search?q=" + encodeURIComponent(url) + "&resolve=true&limit=5"
    SessionManager.authenticatedRequest("GET", searchPath, null,
        function (json) {
            console.log("[UrlRouter] search resolve succeeded:", JSON.stringify(json).substring(0, 300))
            if (json.statuses && json.statuses.length > 0)
                onStatus(json.statuses[0].id)
            else if (json.accounts && json.accounts.length > 0)
                onProfile(json.accounts[0].id)
            else
                onUnhandled()
        },
        function (status, message) {
            console.log("[UrlRouter] search resolve FAILED:", status, message)
            onUnhandled()
        })
}
