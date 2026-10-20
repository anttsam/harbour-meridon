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

var _removeListener = null

// Called once by FeedCarouselView.qml's Component.onCompleted, alongside
// setDirtyListener() above.
function setRemoveListener(fn) {
    _removeListener = fn
}

// For a feed the caller already knows LOCALLY should no longer be in the
// carousel - dismiss/delete/unfollow all know exactly which id just
// stopped belonging, so there's no need for a full loadFeeds() round-trip
// (two GET requests, then feedsModel.clear() + rebuild of everything) just
// to have the server tell us what we already know. Also handles the
// evict-cached-content bookkeeping directly, same as loadFeeds()'s own
// dropped-id diff, since a removed feed's content is exactly as stale as
// a dismissed/unfollowed one's.
function removeFeed(feedId) {
    var idx = -1
    for (var i = 0; i < feeds.length; i++) {
        if (feeds[i].id === feedId) {
            idx = i
            break
        }
    }
    if (idx === -1)
        return

    feeds.splice(idx, 1)
    evictFeedContent(feedId)

    if (_removeListener)
        _removeListener(feedId)
}

// Registered as SessionManager's logout listener - without this, a relogin
// reused feedContent entries whose ListModel died with the previous
// session's FeedCarouselView (dead QObject refs).
function resetState() {
    feeds = []
    currentFeed = null
    loaded = false
    feedContent = {}
    _feedContentMRU = []
    dirty = false
    _dirtyListener = null
    _removeListener = null
}

SessionManager.onLogout(resetState)

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

// Recency cap on top of the dismiss/delete/unfollow eviction in loadFeeds()
// below - that only handles a feed leaving getFeeds() entirely, but someone
// following many lists/hashtags accumulates a live ListModel for every one
// they've ever swiped to THIS SESSION even if most are pinned and never
// revisited. "home" is exempt - it's the default landing feed, always
// expected to be there instantly regardless of what else has been visited
// since.
var _feedContentMRU = [] // feed ids, most-recently-touched last
var MAX_CACHED_FEEDS = 5

function _touchFeedMRU(feedId) {
    var idx = _feedContentMRU.indexOf(feedId)
    if (idx !== -1)
        _feedContentMRU.splice(idx, 1)
    _feedContentMRU.push(feedId)

    // "home" doesn't count against the cap and is never evicted - counting
    // only the others means home being untouched for a while (globally the
    // oldest entry) can't block eviction of everything newer than it.
    var others = _feedContentMRU.filter(function(id) { return id !== "home" })
    while (others.length > MAX_CACHED_FEEDS) {
        evictFeedContent(others.shift())
    }
}

function getFeedContent(feedId, anchor) {
    _touchFeedMRU(feedId)
    if (!feedContent[feedId]) {
        feedContent[feedId] = {
            model: Qt.createQmlObject("import QtQuick 2.0; ListModel {}",
                anchor, "FeedContentModel"),
            busy: false,
            nextCursor: "",
            lastLoadMoreCursor: "",
            loadedOnce: false,
            // Registered by whichever FeedPane is showing this feed, so
            // refreshFeedContent() can keep that pane's scroll position
            // across an insert at the top no matter who triggered the
            // refresh (the pane's own menu, or the cover). keeperOwner
            // lets the pane unregister only itself on destruction.
            positionKeeper: null,
            keeperOwner: null
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

// Drops a feed's cached posts/model once it's no longer in getFeeds() (see
// loadFeeds()'s finish(), the only real caller). The map entry is dropped
// immediately so a fresh getFeedContent() call for the same id (e.g. the
// user re-adds the same list/hashtag right after) starts clean rather than
// racing this eviction, but the actual QObject destroy() is deferred by one
// event-loop tick: a FeedPane whose delegate is still alive somewhere in the
// carousel's SlideshowView cache (e.g. this feed was dismissed from
// ListManagePage while its pane is still cached from an earlier swipe) may
// still have listView.model bound to it until the carousel's own
// populateFeeds() finishes reacting to the same feed list change - deferring
// lets that settle first instead of freeing the model out from under a
// still-bound view. Sailfish's Qt (5.6) predates Qt.callLater() (added in
// 5.10), hence the zero-interval Timer instead - a QML type can't be
// instantiated directly from a .pragma library, so it's built the same way
// getFeedContent() builds its ListModels: via Qt.createQmlObject(), parented
// to the model it's about to destroy so it's cleaned up right along with it.
function evictFeedContent(feedId) {
    var content = feedContent[feedId]
    if (!content)
        return

    delete feedContent[feedId]
    var mruIdx = _feedContentMRU.indexOf(feedId)
    if (mruIdx !== -1)
        _feedContentMRU.splice(mruIdx, 1)

    console.log("[FeedsManager] evicting cached content for", feedId,
        "(", content.model.count, "posts)")

    var timer = Qt.createQmlObject(
        "import QtQuick 2.0; Timer { interval: 0; running: true; repeat: false }",
        content.model, "FeedContentEvictionTimer")
    timer.triggered.connect(function() {
        content.model.destroy()
    })
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

    var path = _feedPath(feed, 20)
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

// Timeline endpoint for a feed with the page size already applied, so
// callers just append further &params. Shared by loadFeedContent() and
// refreshFeedContent() so the two can't drift apart.
function _feedPath(feed, limit) {
    if (feed.type === "local")
        return "/api/v1/timelines/public?local=true&limit=" + limit
    if (feed.type === "federated")
        return "/api/v1/timelines/public?limit=" + limit
    if (feed.type === "list")
        return "/api/v1/timelines/list/" + encodeURIComponent(feed.value) + "?limit=" + limit
    if (feed.type === "hashtag")
        return "/api/v1/timelines/tag/" + encodeURIComponent(feed.value) + "?limit=" + limit
    // "home" - the default/main timeline
    return "/api/v1/timelines/home?limit=" + limit
}

var REFRESH_PAGE_SIZE = 40
var REFRESH_MAX_PAGES = 3

// Pull-to-refresh that keeps what's already loaded: fetches the newest
// page(s), then matches them against the model by timelineId. Posts not in
// the model yet are inserted at the top (so scrolling up reveals everything
// missed in between), posts already in it are updated in place (like/boost/
// reply counts, edits, poll results, "ago" text) - nothing is cleared, and
// nextCursor/lastLoadMoreCursor stay put since they belong to the old end of
// the list. If the newest pages never reach a post already in the model
// (more than ~REFRESH_PAGE_SIZE * REFRESH_MAX_PAGES posts missed), there's
// an unfillable gap, so it falls back to replacing the contents entirely,
// same as a full reload. Nothing touches the model until every page has
// arrived, so a failure part-way leaves it exactly as it was. Falls back to
// a plain full load when nothing has been loaded yet. onDone has the same
// shape as loadFeedContent()'s, plus a fifth argument: how many posts were
// added (0 when nothing new, or when it fell back to a plain full load).
// If the feed's bucket has a positionKeeper(count, insert) registered, that
// is called instead of inserting directly, so the pane that owns the actual
// ListView can keep its scroll position across the insert by calling
// insert() itself at the right moment - without it a view sitting at the
// top just shows the new posts, pushing what you were reading down. The
// posts always end up inserted exactly once even if the keeper throws (e.g.
// its pane was destroyed while the request was in flight).
function refreshFeedContent(feed, anchor, onDone) {
    var content = getFeedContent(feed.id, anchor)

    // Something else is already fetching this feed - that fetch will land
    // in the same model, so there's nothing for this one to add. Still
    // report done so the caller's own busy flag can't get stuck.
    if (content.busy) {
        onDone(true, false, "", 0, 0)
        return
    }

    if (!content.loadedOnce || content.model.count === 0) {
        loadFeedContent(feed, true, anchor, onDone)
        return
    }

    content.busy = true

    function indexByTimelineId() {
        var map = {}
        for (var i = 0; i < content.model.count; i++) {
            var tid = content.model.get(i).timelineId
            if (tid)
                map[tid] = i
        }
        return map
    }

    var known = indexByTimelineId()
    var collected = []  // every row fetched, newest first - for the replace fallback
    var newRows = []    // rows newer than anything already in the model
    var knownRows = []  // fetched rows that are already in the model
    var overlap = false
    var pages = 0

    function finish(lastCursor) {
        if (collected.length === 0) {
            content.busy = false
            onDone(true, false, "", 0, 0)
            return
        }

        if (overlap) {
            // Indices are looked up again here rather than reused from the
            // start of the request, in case the model changed meanwhile.
            var current = indexByTimelineId()
            var boundary = 0  // model index of the oldest post this fetch reached
            for (var k = 0; k < knownRows.length; k++) {
                var row = knownRows[k]
                var idx = current[row.timelineId]
                if (idx === undefined)
                    continue
                boundary = Math.max(boundary, idx)
                var existing = content.model.get(idx)
                for (var key in row) {
                    if (existing[key] !== row[key])
                        content.model.setProperty(idx, key, row[key])
                }
            }

            // Drop posts that have left the timeline since they were loaded
            // (deleted - including from another list or the profile - or
            // newly muted/filtered): anything newer than the oldest post we
            // reached that the fetch didn't return. What's older than that
            // wasn't covered by this fetch, so it's left alone.
            var fetched = {}
            for (var f = 0; f < collected.length; f++)
                fetched[collected[f].timelineId] = true
            var removed = 0
            for (var m = boundary - 1; m >= 0; m--) {
                var mid = content.model.get(m).timelineId
                if (mid && !fetched[mid]) {
                    content.model.remove(m)
                    removed++
                }
            }
            var inserted = false
            var insertNew = function() {
                if (inserted)
                    return
                inserted = true
                for (var n = 0; n < newRows.length; n++)
                    content.model.insert(n, newRows[n])
            }
            if (content.positionKeeper && newRows.length > 0) {
                try {
                    content.positionKeeper(newRows.length, insertNew)
                } catch (e) {
                    console.warn("[FeedsManager] positionKeeper failed:", e)
                }
            }
            insertNew()
            console.log("[FeedsManager] refreshed", feed.displayName, "-",
                newRows.length, "new,", knownRows.length, "updated,", removed, "removed")
        } else {
            content.model.clear()
            for (var c = 0; c < collected.length; c++)
                content.model.append(collected[c])
            content.nextCursor = lastCursor
            content.lastLoadMoreCursor = ""
            console.log("[FeedsManager] refreshed", feed.displayName,
                "- gap too large, replaced", collected.length, "posts")
        }

        content.busy = false
        onDone(true, false, "", 0, newRows.length)
    }

    function fetchPage(maxId) {
        var path = _feedPath(feed, REFRESH_PAGE_SIZE)
        if (maxId)
            path += "&max_id=" + encodeURIComponent(maxId)

        SessionManager.authenticatedRequest("GET", path, null,
            function(response, linkHeader) {
                var statuses = response || []
                var cursor = PostMapper.parseNextCursor(linkHeader)

                mapStatusesAsync(statuses, function(rows) {
                    pages++
                    for (var r = 0; r < rows.length; r++) {
                        collected.push(rows[r])
                        if (known[rows[r].timelineId] !== undefined) {
                            overlap = true
                            knownRows.push(rows[r])
                        } else if (!overlap) {
                            newRows.push(rows[r])
                        }
                    }

                    if (!overlap && cursor.length > 0 && pages < REFRESH_MAX_PAGES)
                        fetchPage(cursor)
                    else
                        finish(cursor)
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

    console.log("[FeedsManager] refreshing (merge) feed:", feed.displayName)
    fetchPage("")
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

        var previousIds = {}
        for (var pi = 0; pi < feeds.length; pi++)
            previousIds[feeds[pi].id] = true

        feeds = pinned.concat(listRows || []).concat(hashtagRows || [])
        loaded = true
        if (!currentFeed)
            currentFeed = feeds[0]

        // Anything that dropped out (dismissed, deleted, unfollowed) since
        // the last loadFeeds() no longer needs its cached posts kept around.
        // Best-effort: a cache-cleanup failure here must never be able to
        // block onDone() below, or the carousel never hears feeds changed.
        try {
            for (var i = 0; i < feeds.length; i++)
                delete previousIds[feeds[i].id]
            for (var droppedId in previousIds)
                evictFeedContent(droppedId)
        } catch (e) {
            console.warn("[FeedsManager] evicting stale feed content failed:", e)
        }

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
