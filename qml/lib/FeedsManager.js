.pragma library
.import "SessionManager.js" as SessionManager
.import "PostMapper.js" as PostMapper
.import "PinnedFeedsStorage.js" as PinnedFeedsStorage

// In-memory cache, shared across every QML file that imports this module
var feeds = []       // [{id, type, value, pinned, displayName, avatarUrl}]
var currentFeed = null
var loaded = false

// WorkerScript is a QML item type, not something a .pragma library can
// instantiate itself - wired up once from harbour-meridon.qml's root
// Component.onCompleted, which owns the actual WorkerScript instance for
// the app's whole lifetime. See mapStatusesAsync()'s own comment for why
// this exists at all.
var _worker = null
var _pendingCallbacks = {}
var _nextRequestId = 1

function setWorker(item) {
    console.log("[FeedsManager] worker attached")
    _worker = item
}

// Called by that same WorkerScript instance's own onMessage handler.
function handleWorkerMessage(message) {
    console.log("[FeedsManager] handleWorkerMessage for request", message.requestId,
        "with", (message.rows || []).length, "rows - pending:", Object.keys(_pendingCallbacks).join(","))
    var callback = _pendingCallbacks[message.requestId]
    if (!callback) {
        console.warn("[FeedsManager] no pending callback for request", message.requestId)
        return
    }
    delete _pendingCallbacks[message.requestId]
    callback(message.rows)
}

// Mapping a full page of statuses - parsing each one's HTML content
// through several regex passes, JSON.stringify-ing its emoji/media/
// mention data, ... - is real, synchronous CPU work. For a ~40-post
// timeline response, enough of it landing in one go on the main thread
// visibly stalls everything else running there, including Silica's own
// BusyIndicator animation (its RotationAnimator survives a busy GUI
// thread only as long as the render thread itself never gets starved of
// CPU time, which a big enough synchronous burst on a phone-class CPU
// can still cause). This offloads the mapping loop itself to a genuine
// separate thread via WorkerScript, so the main thread only ever does
// cheap ListModel.append() calls with rows that are already fully
// computed. Falls back to mapping synchronously right here if no worker
// has been wired up yet (shouldn't normally happen once
// harbour-meridon.qml's own Component.onCompleted has run, but keeps
// every caller working regardless of ordering) or for an empty page
// (not worth a thread round-trip for nothing).
function mapStatusesAsync(statuses, callback) {
    if (!_worker || statuses.length === 0) {
        var rows = []
        for (var i = 0; i < statuses.length; i++)
            rows.push(PostMapper.mapStatus(statuses[i], PostMapper.formatTimeAgo))
        callback(rows)
        return
    }

    var requestId = _nextRequestId++
    _pendingCallbacks[requestId] = callback
    console.log("[FeedsManager] dispatching request", requestId, "with", statuses.length, "statuses to worker")
    _worker.sendMessage({ requestId: requestId, statuses: statuses })
}

// Set by any page that changes which feeds/lists/hashtags should appear
// in the Home carousel from OUTSIDE the carousel's own direct wiring -
// e.g. HashtagPage.qml's follow/unfollow toggle, reachable from anywhere
// via LinkHandler.js, unlike ListManagePage.qml, which has fixed, known
// entry points (MainPage.qml/MoreSlide.qml). Deliberately NOT "refresh
// on every page pop" - an earlier version of this did that and it kept
// resetting the carousel back to Home and losing scroll position for
// completely unrelated navigation that never touched feeds at all
// (image viewer, post detail, compose, ...). markDirty() is only ever
// called from an actual feed-affecting mutation, never from generic
// navigation.
//
// The actual refresh happens immediately, via _dirtyListener - there's
// only ever one real reader of this data at a time (FeedCarouselView,
// which subscribes once in its own Component.onCompleted and outlives
// every page that could call markDirty()), so a direct callback is both
// simpler and more reliable than a page having to poll/check a flag on
// its own: it fires the instant something changes, while the carousel
// is invisible (MainPage backgrounded behind whatever page made the
// change) rather than visibly refreshing under the user's eyes the
// moment they return. The flag stays as a narrow fallback for the
// unlikely case markDirty() fires before the listener has registered -
// harmless if it's never consumed, since FeedCarouselView's own very
// first load (via its initialLoadTimer) already reads current state
// regardless of whether this was ever set.
var dirty = false
var _dirtyListener = null

function markDirty() {
    if (_dirtyListener) {
        _dirtyListener()
    } else {
        dirty = true
    }
}

function isDirty() {
    return dirty
}

function clearDirty() {
    dirty = false
}

// Called once by FeedCarouselView.qml's Component.onCompleted.
function setDirtyListener(fn) {
    _dirtyListener = fn
    dirty = false
}

function defaultHomeFeed() {
    var seed = PinnedFeedsStorage.defaultHomeFeed()
    seed.avatarUrl = ""
    return seed
}

function getFeeds() {
    return feeds
}

function getCurrentFeed() {
    if (!currentFeed)
        currentFeed = defaultHomeFeed()
    return currentFeed
}

function setCurrentFeed(feed) {
    currentFeed = feed
}

function isLoaded() {
    return loaded
}

// Per-feed post content, keyed by feed id - owned here (not by whichever
// FeedPane delegate happens to be displaying it) so a feed's loaded posts
// and pagination cursor survive its delegate being destroyed and recreated
// as the carousel's SlideshowView recycles items while swiping. "busy" is
// kept here too (rather than only as FeedPane's own local UI property) so
// that swiping away from a feed and back while its fetch is still in
// flight can't fire a second overlapping request for the same feed.
// lastLoadMoreCursor is the same reasoning, for the same "recycled
// delegate" lifetime: it guards FeedPane's checkLoadMore() against
// firing more than once for the same page (atYEnd can read true
// transiently for reasons that have nothing to do with the user actually
// scrolling, e.g. geometry settling as a swiped-back-to pane
// reactivates) - living on the FeedPane instance itself wouldn't survive
// exactly the delegate recreation this guard needs to survive.
var feedContent = {} // feedId -> {model, busy, nextCursor, lastLoadMoreCursor, loadedOnce}

function getFeedContent(feedId, anchor) {
    if (!feedContent[feedId]) {
        feedContent[feedId] = {
            model: Qt.createQmlObject("import QtQuick 2.0; ListModel {}",
                anchor, "FeedContentModel"),
            busy: false,
            nextCursor: "",
            lastLoadMoreCursor: "",
            loadedOnce: false
        }
    }
    return feedContent[feedId]
}

// Read-only lookup, unlike getFeedContent() above - never creates a new
// bucket (and therefore never calls Qt.createQmlObject with a
// caller-supplied anchor). Safe to call from contexts that can't
// guarantee a stable, long-lived QObject to parent a freshly-created
// bucket to - currently just CoverPage.qml, which (unlike
// FeedCarouselView, instantiated once and kept alive for the whole app
// session) isn't guaranteed to stay alive the same way. Returns null if
// that feed hasn't actually been loaded by anything yet.
function peekFeedContent(feedId) {
    return feedContent[feedId] || null
}

// Fetches one page of a specific feed's posts (moved here from the old
// TimelineView.qml, which used to hold a single shared ListModel for
// whichever feed was "current" - now every feed has its own entry in
// feedContent, so there's no "stale response for a feed you've since
// switched away from" case to guard against any more: a response always
// lands in the bucket for the feed it was requested for, whether or not
// that feed's pane is even instantiated right now. onDone(success,
// error401, message, status) fires once - translating/formatting the
// message into UI text is left to the QML caller (FeedPane), same as
// SessionManager's own request callbacks already do everywhere else.
// loadedOnce only ever gets set on success, so a feed that failed to load
// gets a fresh automatic attempt the next time it becomes current, rather
// than silently staying empty forever.
function loadFeedContent(feed, reset, anchor, onDone) {
    var content = getFeedContent(feed.id, anchor)

    if (content.busy && !reset)
        return

    content.busy = true
    if (reset) {
        content.nextCursor = ""
        content.lastLoadMoreCursor = ""
    }

    var path
    if (feed.type === "local") {
        path = "/api/v1/timelines/public?local=true&limit=40"
    } else if (feed.type === "federated") {
        path = "/api/v1/timelines/public?limit=40"
    } else if (feed.type === "list") {
        path = "/api/v1/timelines/list/" + encodeURIComponent(feed.value) + "?limit=40"
    } else if (feed.type === "hashtag") {
        path = "/api/v1/timelines/tag/" + encodeURIComponent(feed.value) + "?limit=40"
    } else {
        // "home" - the default/main timeline
        path = "/api/v1/timelines/home?limit=40"
    }
    if (!reset && content.nextCursor.length > 0)
        path += "&max_id=" + encodeURIComponent(content.nextCursor)

    console.log("[FeedsManager] fetching", reset ? "(refresh)" : "(load more)",
        "feed:", feed.displayName)

    SessionManager.authenticatedRequest("GET", path, null,
        function(response, linkHeader) {
            var statuses = response || []
            console.log("[FeedsManager] got", statuses.length, "posts for", feed.displayName)
            var nextCursor = PostMapper.parseNextCursor(linkHeader)

            mapStatusesAsync(statuses, function(rows) {
                content.busy = false
                content.loadedOnce = true

                if (reset)
                    content.model.clear()

                for (var i = 0; i < rows.length; i++)
                    content.model.append(rows[i])

                content.nextCursor = nextCursor
                onDone(true, false, "", 0)
            })
        },
        function(status, message) {
            content.busy = false
            if (status === 401) {
                console.warn("[FeedsManager] session invalid, forcing re-login")
                onDone(false, true, "", status)
            } else {
                onDone(false, false, message, status)
            }
        }
    )
}

// Builds the carousel's feed set from three sources: the locally-pinned
// non-list feeds (see PinnedFeedsStorage.js - currently just Home),
// EVERY list the user currently has (GET /api/v1/lists), and every
// hashtag the user currently follows (GET /api/v1/followed_tags) -
// fetched fresh each time, both show up automatically with no separate
// "add to carousel" step, mirroring how they behaved as part of AT
// Proto's savedFeedsPrefV2 before. A list the user explicitly removed via
// ListManagePage.qml (tracked in PinnedFeedsStorage's dismissed-lists
// set) is skipped so it doesn't just reappear on the next load - hashtags
// need no equivalent opt-out, since following/unfollowing a hashtag is
// already itself an explicit, server-side toggle. onDone(success) fires
// once feeds/currentFeed are ready to read via getFeeds()/getCurrentFeed().
function loadFeeds(onDone) {
    var pinned = PinnedFeedsStorage.loadFeeds().map(function(row) {
        return {
            id: row.id,
            type: row.type,
            value: row.value,
            pinned: row.pinned,
            displayName: row.displayName,
            avatarUrl: ""
        }
    })

    var dismissedIds = PinnedFeedsStorage.getDismissedListIds()
    var dismissedHashtagIds = PinnedFeedsStorage.getDismissedHashtagIds()

    var listRows = null
    var hashtagRows = null
    var pending = 2

    function finish() {
        if (pending > 0)
            return

        feeds = pinned.concat(listRows || []).concat(hashtagRows || [])
        loaded = true
        if (!currentFeed)
            currentFeed = feeds[0]
        console.log("[FeedsManager] loaded", feeds.length, "feeds (",
            (listRows || []).length, "lists,", (hashtagRows || []).length, "hashtags )")
        onDone(true)
    }

    SessionManager.authenticatedRequest("GET", "/api/v1/lists", null,
        function(response) {
            var lists = response || []
            listRows = lists
                .filter(function(l) { return dismissedIds[l.id] !== true })
                .map(function(l) {
                    return {
                        id: "list-" + l.id,
                        type: "list",
                        value: l.id,
                        pinned: true,
                        displayName: l.title || "Untitled list",
                        avatarUrl: ""
                    }
                })
            pending -= 1
            finish()
        },
        function(status, message) {
            console.warn("[FeedsManager] loading lists failed:", status, message)
            listRows = [] // still show Home/hashtags even if lists couldn't be fetched
            pending -= 1
            finish()
        }
    )

    SessionManager.authenticatedRequest("GET", "/api/v1/followed_tags?limit=40", null,
        function(response) {
            var tags = response || []
            hashtagRows = tags
                .filter(function(t) { return dismissedHashtagIds[t.name] !== true })
                .map(function(t) {
                    return {
                        id: "hashtag-" + t.name,
                        type: "hashtag",
                        value: t.name,
                        pinned: true,
                        displayName: "#" + t.name,
                        avatarUrl: ""
                    }
                })
            pending -= 1
            finish()
        },
        function(status, message) {
            console.warn("[FeedsManager] loading followed hashtags failed:", status, message)
            hashtagRows = [] // still show Home/lists even if hashtags couldn't be fetched
            pending -= 1
            finish()
        }
    )
}
