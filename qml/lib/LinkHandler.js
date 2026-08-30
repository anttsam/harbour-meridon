.pragma library
.import "SessionManager.js" as SessionManager
.import "UrlRouter.js" as UrlRouter

// Classifies a tapped <a href> from rendered post/bio HTML.
// mentionsByHref/tagsByHref (both optional) are the structured
// {href: {...}} maps PostMapper.mapStatus() builds from a status's own
// mentions/tags arrays - checked first since they're exact, no guessing
// involved. When absent (there's no equivalent structured data for
// account bios - Mastodon's Account entity has no parallel to a status's
// mentions/tags), falls back to Mastodon's own consistent URL
// conventions: a bare "/@username" path is a profile, "/tags/name" is a
// hashtag. Anything else is treated as a plain external link.
function classifyLink(href, mentionsByHref, tagsByHref) {
    if (mentionsByHref && mentionsByHref[href])
        return { type: "mention", accountId: mentionsByHref[href].id }
    if (tagsByHref && tagsByHref[href])
        return { type: "hashtag", name: tagsByHref[href].name }

    try {
        var path = href.replace(/^https?:\/\/[^/]+/i, "")

        var tagMatch = path.match(/^\/tags\/([^/?#]+)/i)
        if (tagMatch)
            return { type: "hashtag", name: decodeURIComponent(tagMatch[1]) }

        var mentionMatch = path.match(/^\/@([^/?#]+)\/?$/)
        if (mentionMatch)
            return { type: "unresolvedMention", href: href }
    } catch (e) {
        // malformed href - fall through to treating it as a plain link
    }

    return { type: "external", href: href }
}

// pageStack: the calling page's PageStack (a QML object, so it can't be
// looked up from inside this .pragma library script - every caller
// already has one in scope and just passes it through).
function openLink(href, pageStack, mentionsByHref, tagsByHref) {
    var link = classifyLink(href, mentionsByHref, tagsByHref)

    if (link.type === "hashtag") {
        pageStack.push(Qt.resolvedUrl("../pages/HashtagPage.qml"), { hashtag: link.name })
    } else if (link.type === "mention") {
        pageStack.push(Qt.resolvedUrl("../pages/UserProfilePage.qml"), { did: link.accountId })
    } else if (link.type === "unresolvedMention") {
        resolveProfileLink(link.href, pageStack)
    } else {
        // No structured mention/tag data backed this href, so it's either
        // a genuinely external link or a Mastodon (or fediverse) post/
        // profile permalink someone pasted as plain text instead of using
        // a real quote-post attach or @mention - same resolution
        // UrlRouter.js already does for links the OS hands this app.
        UrlRouter.resolveAndRoute(link.href,
            function (statusId) {
                pageStack.push(Qt.resolvedUrl("../pages/PostDetailPage.qml"), { postUri: statusId })
            },
            function (accountId) {
                pageStack.push(Qt.resolvedUrl("../pages/UserProfilePage.qml"), { did: accountId })
            },
            function (tag) {
                pageStack.push(Qt.resolvedUrl("../pages/HashtagPage.qml"), { hashtag: tag })
            },
            function () {
                pageStack.push(Qt.resolvedUrl("../pages/WebViewPage.qml"), { url: link.href })
            })
    }
}

// A "/@username" link with no structured mention data behind it (bios
// only) could be a local or a remote account - resolve=true asks the
// instance to do the WebFinger lookup itself rather than this app trying
// to parse/guess a remote account's id from its profile URL.
function resolveProfileLink(href, pageStack) {
    SessionManager.authenticatedRequest("GET",
        "/api/v2/search?q=" + encodeURIComponent(href) + "&type=accounts&resolve=true&limit=1", null,
        function(response) {
            var accounts = (response && response.accounts) || []
            if (accounts.length > 0) {
                pageStack.push(Qt.resolvedUrl("../pages/UserProfilePage.qml"), { did: accounts[0].id })
            } else {
                pageStack.push(Qt.resolvedUrl("../pages/WebViewPage.qml"), { url: href })
            }
        },
        function(status, message) {
            console.warn("[LinkHandler] profile resolve failed:", status, message)
            pageStack.push(Qt.resolvedUrl("../pages/WebViewPage.qml"), { url: href })
        }
    )
}
