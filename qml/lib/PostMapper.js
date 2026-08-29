.pragma library

// StyledText inserts empty row, not really needed with RichText
function stripTrailingParagraph(html) {
    return (html || "").replace(/<\/p>\s*$/, "")
}

// Shorted the link even further
function styleLinks(html, color) {
    return (html || "").replace(/<a /g, '<a style="text-decoration: none; color: ' + color + ';" ')
}

// Only meaningful together with textFormat: Text.RichText (same
// precondition as styleLinks() above) - RichText's QTextDocument-based
// HTML parser honors CSS margin on block elements like <p>, unlike
// StyledText's fixed tag subset. Adds a bit of breathing room between
// paragraphs beyond Qt's own fairly tight default. margin-top only (never
// margin-bottom, and never on the very first <p>) so consecutive
// paragraphs get exactly one gap between them and nothing trails after
// the last one - avoids reintroducing the dead-space-at-the-end problem
// stripTrailingParagraph() above exists to prevent.
function styleParagraphs(html, marginPx) {
    if (!html)
        return html
    var first = true
    return html.replace(/<p>/g, function() {
        var style = first ? "margin-top: 0; margin-bottom: 0;"
            : "margin-top: " + marginPx + "px; margin-bottom: 0;"
        first = false
        return '<p style="' + style + '">'
    })
}

function shortenLinkText(html) {
    return (html || "")
        .replace(/<span class="invisible">.*?<\/span>/g, "")
        .replace(/<span class="ellipsis">(.*?)<\/span>/g, "$1…")
        .replace(/<span class="">(.*?)<\/span>/g, "$1")
}

// Flattens a Status/Account "emojis" array ([{shortcode, url, static_url}])
// into a {shortcode: url} JSON string - EmojiManager.render()'s expected
// input. JSON-serialized because this always ends up as a ListModel row
// field (or a plain QML string property) rather than a live array, the
// same reason embedImagesJson/mentionsJson/tagsJson/etc. below are strings
// too. static_url is used over the possibly-animated url
function emojiMapJson(emojis) {
    var map = {}
    if (emojis) {
        for (var i = 0; i < emojis.length; i++) {
            map[emojis[i].shortcode] = emojis[i].static_url || emojis[i].url
        }
    }
    return JSON.stringify(map)
}

// Converts one Mastodon status object into the same flat row shape
// mapPost() used to produce, so PostDelegate.qml and every other consumer
// keep working unchanged. timeAgoFn is passed in rather than called
// directly for the same reason mapPost() did: keeps this module free of
// any implicit "now" dependency, easier to reason about/test.
function mapStatus(status, timeAgoFn) {
    // A boost/reblog wraps the original status inside status.reblog  Mastodon nests the
    // reposted content directly. Map the *inner* status as the actual
    // post content, but keep the repost attribution from the outer
    // wrapper's own account.
    var isRepost = !!status.reblog
    var repostByName = isRepost ? (status.account.display_name || "") : ""
    var repostByHandle = isRepost ? (status.account.acct || "") : ""
    var inner = isRepost ? status.reblog : status

    var images = []
    if (inner.media_attachments) {
        for (var j = 0; j < inner.media_attachments.length; j++) {
            var att = inner.media_attachments[j]
            if (att.type !== "image")
                continue
            var meta = att.meta && att.meta.original
            var ratio = (meta && meta.aspect) ? meta.aspect : 1.33
            ratio = Math.max(0.5, Math.min(ratio, 1.91))
            images.push({
                thumbUrl: att.preview_url,
                fullsizeUrl: att.url,
                alt: att.description || "",
                aspectRatio: ratio
            })
        }
    }

    // Mastodon's card.type is "link", "photo", "video", or "rich" - the
    // latter three are oEmbed-backed cards for things like YouTube videos
    // or podcast episodes, carrying an <iframe> in card.html for playback
    // on the source site. There's no safe/practical way to render that
    // iframe inline in a scrolling list (arbitrary third-party HTML, and
    // no per-item embedded WebView), but every type shares the same
    // title/description/image/url fields PostLinkCard.qml already
    // displays, so all of them get a tappable preview card rather than
    // only "link" ones - tapping it opens the real page to actually
    // play/listen, same as it already does for plain links.
    var external = null
    if (inner.card && inner.card.url) {
        external = {
            uri: inner.card.url,
            title: inner.card.title || "",
            description: inner.card.description || "",
            thumbUrl: inner.card.image || "",
            domain: extractDomain(inner.card.url)
        }
    }

    // Mastodon's own equivalent of an autoplaying "GIF" is a media
    // attachment of type "gifv" (a silent, looping, autoplaying video),
    // not a link embed the way Bluesky's GIF picker worked - so this
    // folds into the same videoJson path as a real video, flagged
    // isGif:true, rather than a separate gifJson field.
    var video = null
    if (inner.media_attachments) {
        for (var k = 0; k < inner.media_attachments.length; k++) {
            var vatt = inner.media_attachments[k]
            if (vatt.type !== "video" && vatt.type !== "gifv")
                continue
            var vmeta = vatt.meta && vatt.meta.original
            // Mastodon's video_metadata (unlike image_geometry) never sets
            // an "aspect" field, only width/height - confirmed against
            // media_attachment.rb. Compute it ourselves; the 1.78 fallback
            // was silently applying to every video (not just ones missing
            // metadata), which is why portrait video always rendered as
            // if it were landscape.
            var vRatio = (vmeta && vmeta.width && vmeta.height) ? (vmeta.width / vmeta.height) : 1.78
            video = {
                playlistUrl: vatt.url,
                thumbnailUrl: vatt.preview_url || "",
                alt: vatt.description || "",
                aspectRatio: Math.max(0.5, Math.min(vRatio, 1.91)),
                isGif: vatt.type === "gifv"
            }
            break
        }
    }

    // Maps each @mention/#hashtag <a href> in postText's HTML to the
    // structured data Mastodon already includes alongside content -
    // href is the exact key PostDelegate.qml's linkAt() lookup returns,
    // so no URL-pattern guessing is needed to know a tapped link is a
    // mention (and which account) or a hashtag (and which name). See
    // LinkHandler.js, which also has a URL-pattern fallback for contexts
    // (like profile bios) that don't get this structured data at all.
    var mentionsByHref = {}
    if (inner.mentions) {
        for (var m = 0; m < inner.mentions.length; m++) {
            var mn = inner.mentions[m]
            mentionsByHref[mn.url] = { id: mn.id, acct: mn.acct }
        }
    }

    // Mastodon's status object only gives in_reply_to_account_id, no name/
    // handle. For a self-reply (continuing your own thread) that account
    // is just the post's own author - already known. For a genuine reply
    // to someone else, that account is reliably the FIRST entry in
    // mentions (the reply text is prefixed with "@theirhandle", which
    // Mastodon always includes there). Verified against real replies
    // fetched from live public timelines.
    var isReply = !!inner.in_reply_to_id
    var replyToHandle = ""
    // Only ever populated for the self-reply case - Mastodon's Mention
    // entity (used for the "replying to someone else" case below) has no
    // display_name field at all, just {id, username, url, acct}, so
    // there's no name available there without an extra API call per post.
    var replyToName = ""
    if (isReply) {
        if (inner.in_reply_to_account_id === inner.account.id) {
            replyToHandle = inner.account.acct
            replyToName = inner.account.display_name || ""
        } else if (inner.mentions) {
            for (var rm = 0; rm < inner.mentions.length; rm++) {
                if (inner.mentions[rm].id === inner.in_reply_to_account_id) {
                    replyToHandle = inner.mentions[rm].acct
                    break
                }
            }
        }
    }

    var tagsByHref = {}
    if (inner.tags) {
        for (var t = 0; t < inner.tags.length; t++) {
            var tg = inner.tags[t]
            tagsByHref[tg.url] = { name: tg.name }
        }
    }

    var poll = mapPoll(inner.poll)

    return {
        uri: inner.id,
        authorId: inner.account.id,
        displayName: inner.account.display_name || "",
        handle: inner.account.acct,
        avatarUrl: inner.account.avatar || "",
        // Pre-rendered HTML (e.g. "<p>text <a href=...>link</a></p>"), not
        // raw text - the AT Proto version's postText was plain. Rendered
        // with textFormat: Text.StyledText in PostDelegate.qml.
        postText: stripTrailingParagraph(shortenLinkText(inner.content)),
        // Both left as raw ":shortcode:" text - substituted at render time
        // by EmojiManager.render() (see its own comment for why), not baked
        // in here.
        postEmojisJson: emojiMapJson(inner.emojis),
        authorEmojisJson: emojiMapJson(inner.account.emojis),
        // Only meaningful when isRepost - the *outer* status.account is the
        // booster, a different account (with its own emoji set) than the
        // inner post's own author above.
        repostByEmojisJson: isRepost ? emojiMapJson(status.account.emojis) : "{}",
        likeCount: inner.favourites_count || 0,
        repostCount: inner.reblogs_count || 0,
        replyCount: inner.replies_count || 0,
        favourited: !!inner.favourited,
        reblogged: !!inner.reblogged,
        bookmarked: !!inner.bookmarked,
        timeAgo: timeAgoFn(inner.created_at),
        embedImagesJson: JSON.stringify(images),
        externalJson: external ? JSON.stringify(external) : "",
        mentionsJson: JSON.stringify(mentionsByHref),
        tagsJson: JSON.stringify(tagsByHref),
        // Vanilla Mastodon has no native quote-post concept - always
        // empty, so PostDelegate.qml's quote-card UI simply never renders.
        quoteJson: "",
        videoJson: video ? JSON.stringify(video) : "",
        pollJson: poll ? JSON.stringify(poll) : "",
        isRepost: isRepost,
        repostByName: repostByName,
        repostByHandle: repostByHandle,
        isReply: isReply,
        replyToHandle: replyToHandle,
        replyToName: replyToName,
        // Mastodon's own local permalink for this status - used for the
        // "Copy link" context menu action in PostDelegate.qml.
        permalink: inner.url || "",
        // Mastodon's own content warning field - a boost carries none of
        // its own, only the wrapped original post can have one, hence
        // reading it off inner (see inner's own definition above) rather
        // than status.
        spoilerText: inner.spoiler_text || ""
    }
}

// A status can have a poll OR media_attachments, never both (Mastodon's
// own constraint), but never both at once, so PostDelegate.qml doesn't
// need to worry about the two competing for the same layout slot. Shared
// between mapStatus() above (initial load) and PostDelegate.qml's own
// vote submission (POST /api/v1/polls/:id/votes returns this exact same
// Poll shape, freshly updated) so both go through identical mapping.
function mapPoll(poll) {
    if (!poll)
        return null

    return {
        id: poll.id,
        expiresAt: poll.expires_at || "",
        expired: !!poll.expired,
        multiple: !!poll.multiple,
        votesCount: poll.votes_count || 0,
        // Older Mastodon versions/some forks don't expose voters_count
        // separately from votes_count (relevant when multiple is true,
        // where one voter can pick more than one option) - falls back to
        // votes_count so the "N votes" label still has a sane number.
        votersCount: poll.voters_count || poll.votes_count || 0,
        voted: !!poll.voted,
        ownVotes: poll.own_votes || [],
        options: (poll.options || []).map(function(o) {
            return { title: o.title, votesCount: o.votes_count || 0 }
        })
    }
}

// Extracts the max_id cursor for the next page from a Mastodon Link
// response header (RFC 5988), e.g.:
//   <https://instance/api/v1/timelines/home?max_id=123>; rel="next", ...
// Mastodon paginates via this header instead of a cursor field in the
// JSON body the way AT Proto's endpoints did. Returns "" once there's no
// further page (header absent, or no rel="next" entry).
function parseNextCursor(linkHeader) {
    if (!linkHeader)
        return ""

    var parts = linkHeader.split(",")
    for (var i = 0; i < parts.length; i++) {
        if (parts[i].indexOf('rel="next"') === -1)
            continue
        var match = parts[i].match(/[?&]max_id=([^&>]+)/)
        if (match)
            return decodeURIComponent(match[1])
    }
    return ""
}

function extractDomain(url) {
    try {
        var noScheme = url.replace(/^https?:\/\//, "")
        return noScheme.split("/")[0]
    } catch (e) {
        return url
    }
}

function formatTimeAgo(isoString) {
    var then = new Date(isoString)
    var seconds = Math.floor((new Date() - then) / 1000)

    if (seconds < 60) return "now"
    var minutes = Math.floor(seconds / 60)
    if (minutes < 60) return minutes + "m"
    var hours = Math.floor(minutes / 60)
    if (hours < 24) return hours + "h"
    var days = Math.floor(hours / 24)
    return days + "d"
}

// Abbreviates large counts (likes/reposts/replies) the way Bluesky's own
// app does: 12910 -> "12.9k", 10100022 -> "10.1M". Drops a trailing ".0"
// for round numbers (1000 -> "1k", not "1.0k").
function formatCount(n) {
    n = n || 0

    if (n < 1000)
        return String(n)

    if (n < 1000000) {
        var k = n / 1000
        return (k % 1 === 0 ? k.toFixed(0) : k.toFixed(1)) + "k"
    }

    var m = n / 1000000
    return (m % 1 === 0 ? m.toFixed(0) : m.toFixed(1)) + "M"
}
