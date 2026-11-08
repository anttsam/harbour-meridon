.pragma library

// Pure decision logic for restoring the Home feed's reading position from the
// server-side "home" marker (GET/POST /api/v1/markers).

var PAGE_SIZE = 40            // Mastodon's maximum for timelines
var RESTORE_MAX_PAGES = 5     // most pages fetched looking for the marker (200 posts)
var MIN_ROWS_BELOW_MARKER = 10
var WRITE_DEBOUNCE_MS = 5000
var WRITE_RETRIES = 1

// Mastodon ids are numeric strings (snowflakes), too big for a JS number, so
// they are compared as strings: a longer one is newer, same length compares
// lexicographically. Also holds for fixed-length flake ids. -1 if a is older
// than b, 1 if newer, 0 if equal.
function compareIds(a, b) {
    a = String(a || "")
    b = String(b || "")
    if (a.length !== b.length)
        return a.length < b.length ? -1 : 1
    if (a === b)
        return 0
    return a < b ? -1 : 1
}

// rows are newest first, as the timeline returns them. The landing row is the
// first one at or older than the marker: the marker post itself, or the next
// older one if it was deleted, muted or filtered. -1 if every row is newer.
function findLandingIndex(rows, markerId) {
    for (var i = 0; i < rows.length; i++) {
        if (compareIds(rows[i].timelineId, markerId) <= 0)
            return i
    }
    return -1
}

function isCovered(rows, markerId) {
    return findLandingIndex(rows, markerId) >= 0
}

// Newest post the user has had at the top of the
// list - should be written as the new marker.
function shouldWrite(newestSeenId, lastKnownId, userMoved, restoring) {
    if (!newestSeenId || restoring || !userMoved)
        return false
    return !lastKnownId || compareIds(newestSeenId, lastKnownId) > 0
}

// Whether a feed is placed relative to the Following ("home") marker. Home is,
// and a list is a filtered view of it, so a post seen in Following is already
// seen there - except an exclusive list, whose members are hidden from Home
// and so never appear in Following at all. Hashtag, local and federated feeds
// are not subsets of Following. Lists only ever read the marker, see
// FeedPane.writeMarker().
function usesFollowingMarker(feed) {
    if (!feed)
        return false
    if (feed.type === "home")
        return true
    return feed.type === "list" && feed.exclusive !== true
}

// After landing on a row near the end of what was fetched there is little to
// read below it, so one more page is worth fetching if the server has one.
function needsExtraPage(rows, landingIndex, hasCursor) {
    if (!hasCursor || landingIndex < 0)
        return false
    return (rows.length - 1 - landingIndex) < MIN_ROWS_BELOW_MARKER
}
