// Deliberately self-contained, no ".import" of PostMapper.js

function stripTrailingParagraph(html) {
    return (html || "").replace(/<\/p>\s*$/, "")
}

function shortenLinkText(html) {
    return (html || "")
        .replace(/<span class="invisible">.*?<\/span>/g, "")
        .replace(/<span class="ellipsis">(.*?)<\/span>/g, "$1…")
        .replace(/<span class="">(.*?)<\/span>/g, "$1")
}

// Kept in sync with PostMapper.js's own stripQuoteInlineParagraph()/
// htmlToPlainText()/quoteUnavailableText()/mapQuote() - see their comments
// there for the full reasoning.
function stripQuoteInlineParagraph(html) {
    return (html || "").replace(/<p class="quote-inline">[\s\S]*?<\/p>\s*/i, "")
}

function htmlToPlainText(html) {
    return shortenLinkText(html || "")
        .replace(/<\/p>/g, "\n\n")
        .replace(/<br\s*\/?>/gi, "\n")
        .replace(/<[^>]+>/g, "")
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, "\"")
        .replace(/&#39;/g, "'")
        .trim()
}

function quoteUnavailableText(state) {
    switch (state) {
        case "pending": return "Quote pending approval"
        case "rejected": return "Quote request was declined"
        case "revoked": return "Quote permission was revoked"
        case "deleted": return "Quoted post was deleted"
        case "unauthorized": return "You don't have permission to view this quote"
        default: return "Quoted post is unavailable"
    }
}

function mapQuote(quoteField) {
    if (!quoteField)
        return null

    if (quoteField.state === "accepted" && quoteField.quoted_status) {
        var qs = quoteField.quoted_status
        // Kept in sync with PostMapper.js's own mapQuote() - preview_url is
        // a static image on every attachment type, not just "image" ones.
        var qsThumb = (qs.media_attachments && qs.media_attachments.length > 0)
            ? (qs.media_attachments[0].preview_url || "") : ""
        return {
            uri: qs.id,
            authorName: qs.account.display_name || "",
            authorHandle: qs.account.acct,
            authorAvatar: qs.account.avatar || "",
            text: htmlToPlainText(qs.content),
            thumbUrl: qsThumb,
            unavailable: false
        }
    }

    return {
        uri: "",
        authorName: "",
        authorHandle: "",
        authorAvatar: "",
        text: quoteUnavailableText(quoteField.state),
        thumbUrl: "",
        unavailable: true
    }
}

function emojiMapJson(emojis) {
    var map = {}
    if (emojis) {
        for (var i = 0; i < emojis.length; i++) {
            map[emojis[i].shortcode] = emojis[i].static_url || emojis[i].url
        }
    }
    return JSON.stringify(map)
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

function mapPoll(poll) {
    if (!poll)
        return null

    return {
        id: poll.id,
        expiresAt: poll.expires_at || "",
        expired: !!poll.expired,
        multiple: !!poll.multiple,
        votesCount: poll.votes_count || 0,
        votersCount: poll.voters_count || poll.votes_count || 0,
        voted: !!poll.voted,
        ownVotes: poll.own_votes || [],
        options: (poll.options || []).map(function(o) {
            return { title: o.title, votesCount: o.votes_count || 0 }
        })
    }
}

function mapStatus(status, timeAgoFn) {
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

    var video = null
    if (inner.media_attachments) {
        for (var k = 0; k < inner.media_attachments.length; k++) {
            var vatt = inner.media_attachments[k]
            if (vatt.type !== "video" && vatt.type !== "gifv")
                continue
            var vmeta = vatt.meta && vatt.meta.original
            // Kept in sync with PostMapper.js's own mapStatus() - see its
            // comment for why this is computed from width/height rather
            // than trusting a (server-side never-set) "aspect" field.
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

    var mentionsByHref = {}
    if (inner.mentions) {
        for (var m = 0; m < inner.mentions.length; m++) {
            var mn = inner.mentions[m]
            mentionsByHref[mn.url] = { id: mn.id, acct: mn.acct }
        }
    }

    var isReply = !!inner.in_reply_to_id
    var replyToHandle = ""
    // Kept in sync with PostMapper.js's own mapStatus() - only populated
    // for the self-reply case, see its comment for why.
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
    var quote = mapQuote(inner.quote)

    return {
        uri: inner.id,
        authorId: inner.account.id,
        displayName: inner.account.display_name || "",
        handle: inner.account.acct,
        avatarUrl: inner.account.avatar || "",
        postText: stripTrailingParagraph(shortenLinkText(
            inner.quote ? stripQuoteInlineParagraph(inner.content) : inner.content)),
        postEmojisJson: emojiMapJson(inner.emojis),
        authorEmojisJson: emojiMapJson(inner.account.emojis),
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
        quoteJson: quote ? JSON.stringify(quote) : "",
        videoJson: video ? JSON.stringify(video) : "",
        pollJson: poll ? JSON.stringify(poll) : "",
        isRepost: isRepost,
        repostByName: repostByName,
        repostByHandle: repostByHandle,
        isReply: isReply,
        replyToHandle: replyToHandle,
        replyToName: replyToName,
        permalink: inner.url || "",
        spoilerText: inner.spoiler_text || ""
    }
}

WorkerScript.onMessage = function(message) {
    console.log("[FeedMapperWorker] received request", message.requestId, "with",
        (message.statuses || []).length, "statuses")
    var statuses = message.statuses || []
    var rows = []
    for (var i = 0; i < statuses.length; i++) {
        rows.push(mapStatus(statuses[i], formatTimeAgo))
    }
    console.log("[FeedMapperWorker] sending back", rows.length, "rows for request", message.requestId)
    WorkerScript.sendMessage({ requestId: message.requestId, rows: rows })
}
