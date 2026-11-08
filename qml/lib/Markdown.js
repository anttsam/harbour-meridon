.pragma library

// Markdown to the HTML subset Qt 5.6's Text.RichText understands, for Lemmy
// posts and comments (the API hands out the Markdown the author typed; Mastodon
// and PeerTube send HTML). Covers what shows up in practice: paragraphs and
// line breaks, headings, bold/italic/strikethrough, inline and fenced code,
// links and images, bare URLs, quotes, lists, rules and Lemmy's ::: spoiler
// blocks. Tables and nested lists are shown flat, as plain lines.
//
// Self-contained, no ".import", like PostMapper.js.

function escapeHtml(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

function escapeAttr(text) {
    return escapeHtml(text).replace(/"/g, "&quot;")
}

// Only web links are kept, a javascript: or data: href never reaches the label
function safeUrl(url, baseHost) {
    url = url.trim()
    if (/^https?:\/\//i.test(url) || /^mailto:/i.test(url))
        return url
    if (url.charAt(0) === "/" && url.charAt(1) !== "/" && baseHost)
        return "https://" + baseHost + url
    return ""
}

// Inline pieces already turned into HTML are parked in a list and put back
// at the end, so later patterns can't reach into them (a URL's underscores
// are not emphasis)
function inline(text, baseHost) {
    var parked = []
    function park(html) {
        parked.push(html)
        return "\u0001" + (parked.length - 1) + "\u0002"
    }

    var s = escapeHtml(text)

    s = s.replace(/`([^`\n]+)`/g, function (m, code) {
        return park("<code>" + code + "</code>")
    })

    // Images are not shown inline, they would blow up a comment. A link to
    // the image takes their place.
    s = s.replace(/!\[([^\]]*)\]\(([^)\s]+)(?:\s+&quot;[^)]*&quot;)?\)/g, function (m, alt, url) {
        var href = safeUrl(url.replace(/&amp;/g, "&"), baseHost)
        if (href.length === 0)
            return alt
        return park('<a href="' + escapeAttr(href) + '">' + (alt.length > 0 ? alt : "[image]") + "</a>")
    })

    s = s.replace(/\[([^\]]+)\]\(([^)\s]+)(?:\s+&quot;[^)]*&quot;)?\)/g, function (m, label, url) {
        var href = safeUrl(url.replace(/&amp;/g, "&"), baseHost)
        if (href.length === 0)
            return label
        return park('<a href="' + escapeAttr(href) + '">' + emphasis(label) + "</a>")
    })

    s = s.replace(/&lt;(https?:\/\/[^\s&]+)&gt;/g, function (m, url) {
        return park('<a href="' + escapeAttr(url) + '">' + url + "</a>")
    })

    s = s.replace(/(^|[\s(])(https?:\/\/[^\s<]+[^\s<.,;:!?)\]'"])/g, function (m, lead, url) {
        var href = url.replace(/&amp;/g, "&")
        return lead + park('<a href="' + escapeAttr(href) + '">' + url + "</a>")
    })

    s = emphasis(s)

    // Parked pieces can contain placeholders themselves (emphasis inside a link)
    var guard = 0
    while (/\u0001\d+\u0002/.test(s) && guard++ < 5)
        s = s.replace(/\u0001(\d+)\u0002/g, function (m, i) { return parked[Number(i)] })
    return s
}

function emphasis(s) {
    return s
        .replace(/\*\*\*([^*\n]+?)\*\*\*/g, "<b><i>$1</i></b>")
        .replace(/\*\*([^*\n]+?)\*\*/g, "<b>$1</b>")
        .replace(/(^|[^\w])__([^_\n]+?)__(?=[^\w]|$)/g, "$1<b>$2</b>")
        .replace(/(^|[^*\w])\*([^*\s][^*\n]*?)\*(?=[^*\w]|$)/g, "$1<i>$2</i>")
        .replace(/(^|[^\w])_([^_\s][^_\n]*?)_(?=[^\w]|$)/g, "$1<i>$2</i>")
        .replace(/~~([^~\n]+?)~~/g, "<s>$1</s>")
}

var headingRe = /^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$/
var ruleRe = /^\s{0,3}([-*_])(?:\s*\1){2,}\s*$/
var quoteRe = /^\s{0,3}>\s?(.*)$/
var itemRe = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/
var fenceRe = /^\s{0,3}(```|~~~)/
var spoilerRe = /^:::\s*spoiler\s*(.*)$/i

// baseHost (optional): the server the text came from, to resolve /c/name links
function toHtml(markdown, baseHost) {
    var lines = String(markdown || "").replace(/\r\n?/g, "\n").split("\n")
    var out = []
    var i = 0

    while (i < lines.length) {
        var line = lines[i]

        if (line.trim().length === 0) {
            i++
            continue
        }

        var fence = fenceRe.exec(line)
        if (fence) {
            var code = []
            i++
            while (i < lines.length && lines[i].indexOf(fence[1]) !== 0 && !fenceRe.test(lines[i])) {
                code.push(lines[i])
                i++
            }
            i++ // closing fence
            out.push("<pre>" + escapeHtml(code.join("\n")) + "</pre>")
            continue
        }

        var spoiler = spoilerRe.exec(line)
        if (spoiler) {
            var inner = []
            i++
            while (i < lines.length && lines[i].trim() !== ":::") {
                inner.push(lines[i])
                i++
            }
            i++
            out.push("<p><b>" + inline(spoiler[1] || "Spoiler", baseHost) + "</b></p>"
                     + "<blockquote>" + toHtml(inner.join("\n"), baseHost) + "</blockquote>")
            continue
        }

        var heading = headingRe.exec(line)
        if (heading) {
            out.push("<p><b>" + inline(heading[2], baseHost) + "</b></p>")
            i++
            continue
        }

        if (ruleRe.test(line)) {
            out.push("<hr/>")
            i++
            continue
        }

        if (quoteRe.test(line)) {
            var quoted = []
            while (i < lines.length && quoteRe.test(lines[i])) {
                quoted.push(quoteRe.exec(lines[i])[1])
                i++
            }
            out.push("<blockquote>" + toHtml(quoted.join("\n"), baseHost) + "</blockquote>")
            continue
        }

        var item = itemRe.exec(line)
        if (item) {
            var ordered = /\d/.test(item[2].charAt(0))
            var items = []
            while (i < lines.length && itemRe.test(lines[i])) {
                var it = itemRe.exec(lines[i])
                // nesting is not kept, only hinted by an indent
                var indent = it[1].length >= 2 ? "&nbsp;&nbsp;&nbsp;" : ""
                items.push("<li>" + indent + inline(it[3], baseHost) + "</li>")
                i++
            }
            out.push((ordered ? "<ol>" : "<ul>") + items.join("") + (ordered ? "</ol>" : "</ul>"))
            continue
        }

        // Paragraph: runs until a blank line or the start of another block.
        // Lemmy renders a single newline as a line break.
        var para = []
        while (i < lines.length && lines[i].trim().length > 0
               && !(para.length > 0 && (fenceRe.test(lines[i]) || headingRe.test(lines[i])
                    || quoteRe.test(lines[i]) || itemRe.test(lines[i]) || spoilerRe.test(lines[i])
                    || ruleRe.test(lines[i])))) {
            para.push(inline(lines[i], baseHost))
            i++
        }
        out.push("<p>" + para.join("<br>") + "</p>")
    }

    return out.join("")
}
