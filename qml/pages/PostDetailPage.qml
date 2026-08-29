import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager
import "../lib/PostMapper.js" as PostMapper

AppPage {
    id: postDetailPage

    property string postUri: ""

    property bool busy: false
    property string errorText: ""
    property bool repliesLoading: false
    // Drives the footer BusyIndicator, avoid two
    readonly property bool showRepliesSpinner: repliesLoading && !busy

    property var rawFocusPost: null
    property var rawReplies: []
    property var rawAncestors: [] // oldest first - see load()
    property string sortMode: "mostLiked" // oldest | newest | mostLiked

    // parentId -> [child status, ...], built once per load() from the
    // flat context.descendants array (Mastodon has no pre-nested reply tree)
    property var childrenByParent: ({})

    // Index of the focus post within threadModel - shifts based on how
    // many ancestor rows got prepended
    property int focusIndex: 0

    ListModel {
        id: threadModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: threadModel
        cacheBuffer: 4000 //or 8000 nicer scrolling back up

        header: PageHeader {
            title: qsTr("Post")
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Sort: Oldest first")
                onClicked: postDetailPage.applySort("oldest")
                visible: sortMode !== "oldest"
            }
            MenuItem {
                text: qsTr("Sort: Newest first")
                onClicked: postDetailPage.applySort("newest")
                visible: sortMode !== "newest"
            }
            MenuItem {
                text: qsTr("Sort: Most liked")
                onClicked: postDetailPage.applySort("mostLiked")
                visible: sortMode !== "mostLiked"
            }
        }

        delegate: PostDelegate {
            isMainPost: model.isFocusPost === true
            hideReplyHint: true
            // Prevent focus post self loop
            clickable: index !== postDetailPage.focusIndex
            indented: model.indented === true
            showThreadLine: true
        }

        section {
            property: "sectionLabel"
            delegate: SectionHeader {
                text: section
            }
        }

        footer: Item {
            width: parent ? parent.width : 0
            height: postDetailPage.showRepliesSpinner ? Theme.itemSizeLarge : 0

            BusyIndicator {
                anchors.centerIn: parent
                running: postDetailPage.showRepliesSpinner
                visible: running
                size: BusyIndicatorSize.Medium
            }
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: errorText.length > 0
            text: qsTr("Couldn't load post")
            hintText: errorText
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: postDetailPage.busy
        visible: running
        size: BusyIndicatorSize.Large
    }

    Component.onCompleted: load()

    // Set once either request's failure handler sees a 401, so the other
    // one (which may still be in flight) doesn't also try to redirect.
    property bool _sessionExpired: false
    // Holds the raw /context response until rawFocusPost is also known
    // (childrenByParent grouping needs the focus post's own id) - covers
    // the (unusual, since the focus post's own request is normally the
    // smaller/faster of the two) case where /context resolves first.
    property var _pendingContext: null

    function load() {
        if (postUri.length === 0) {
            errorText = qsTr("No post specified")
            return
        }

        busy = true
        repliesLoading = true
        errorText = ""
        threadModel.clear()
        _sessionExpired = false
        _pendingContext = null

        // Two calls, independently resolved (not joined) - the focus post
        // itself is a single small object and typically resolves much
        // faster than /context, which for a large thread can carry
        // hundreds of descendant statuses. Showing the focus post the
        // moment its own request lands - rather than waiting on the
        // (often slower) replies too - noticeably cuts perceived load
        // time for big threads without changing the total time to have
        // everything loaded.
        var statusPath = "/api/v1/statuses/" + encodeURIComponent(postUri)
        var contextPath = statusPath + "/context"

        console.log("[PostDetail] fetching thread for", postUri)

        SessionManager.authenticatedRequest("GET", statusPath, null,
            function(response) {
                busy = false
                if (postDetailPage._sessionExpired)
                    return
                rawFocusPost = response
                _processContextIfReady()
                // Renders just the focus post if /context hasn't landed
                rebuildReplies()
            },
            function(status, message) { postDetailPage._handleLoadFailure(status, message, true) }
        )

        SessionManager.authenticatedRequest("GET", contextPath, null,
            function(response) {
                repliesLoading = false
                if (postDetailPage._sessionExpired)
                    return
                _pendingContext = response || {}
                _processContextIfReady()
            },
            function(status, message) { postDetailPage._handleLoadFailure(status, message, false) }
        )
    }

    function _handleLoadFailure(status, message, isFocusRequest) {
        if (status === 401) {
            if (!_sessionExpired) {
                _sessionExpired = true
                SessionManager.clearSession()
                pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
            }
            return
        }

        console.warn("[PostDetail] request failed:", status, message)

        if (isFocusRequest) {
            busy = false
            if (!rawFocusPost)
                errorText = qsTr("Couldn't load post")
        } else {
            // Replies failed to load
            repliesLoading = false
        }
    }

    // Groups /context's flat descendants array by immediate parent (so
    // buildBestReplyChain() can walk it) and derives rawAncestors/
    // rawReplies, but only once rawFocusPost is known - safe to call
    // any number of times, a no-op until both pieces have arrived.
    function _processContextIfReady() {
        if (!rawFocusPost || !_pendingContext)
            return

        var ancestors = _pendingContext.ancestors || []
        rawAncestors = ancestors.map(function(s) { return { post: s } })
        console.log("[PostDetail] got", rawAncestors.length, "ancestors")

        var descendants = _pendingContext.descendants || []
        childrenByParent = {}
        for (var d = 0; d < descendants.length; d++) {
            var s = descendants[d]
            var pid = s.in_reply_to_id
            if (!childrenByParent[pid])
                childrenByParent[pid] = []
            childrenByParent[pid].push(s)
        }

        rawReplies = (childrenByParent[rawFocusPost.id] || []).map(function(s) { return { post: s } })
        console.log("[PostDetail] got", rawReplies.length, "direct replies")

        _pendingContext = null
        rebuildReplies()
    }

    // getPostThread has no server-side sort parameter
    function applySort(mode) {
        sortMode = mode
        rebuildReplies()
    }

    function rebuildReplies() {
        if (!rawFocusPost)
            return

        // TEMP DIAGNOSTIC
        var rebuildStartMs = Date.now()

        threadModel.clear()

        // Ancestors first, oldest to newest
        for (var a = 0; a < rawAncestors.length; a++) {
            var ancestorRow = PostMapper.mapStatus(rawAncestors[a].post, PostMapper.formatTimeAgo)
            ancestorRow.sectionLabel = ""
            ancestorRow.indented = false
            ancestorRow.hasDisplayedContinuation = true
            // Explicit on every row type (see buildBestReplyChain() and
            // focusRow below too) rather than only ever setting it true on
            // the one row that needs it - ListModel.append() establishes
            // its role schema from the FIRST row appended, so if that row
            // never mentioned isFocusPost at all, a later append() that
            // does could have it silently dropped instead of just reading
            // back false.
            ancestorRow.isFocusPost = false
            threadModel.append(ancestorRow)
        }

        focusIndex = rawAncestors.length

        var focusRow = PostMapper.mapStatus(rawFocusPost, PostMapper.formatTimeAgo)
        focusRow.sectionLabel = ""
        focusRow.indented = false
        focusRow.hasDisplayedContinuation = false
        focusRow.isFocusPost = true
        threadModel.append(focusRow)

        // TEMP DIAGNOSTIC
        //console.log("[PostDetail][perf] ancestors+focus mapped/appended at +" + (Date.now() - rebuildStartMs) + "ms (rebuildReplies-relative)")

        var sorted = rawReplies.slice() // don't mutate the cached array

        if (sortMode === "newest") {
            sorted.sort(function(a, b) {
                return new Date(b.post.created_at) - new Date(a.post.created_at)
            })
        } else if (sortMode === "mostLiked") {
            sorted.sort(function(a, b) {
                return (b.post.favourites_count || 0) - (a.post.favourites_count || 0)
            })
        } else { // oldest
            sorted.sort(function(a, b) {
                return new Date(a.post.created_at) - new Date(b.post.created_at)
            })
        }

        // TEMP DIAGNOSTIC
        //console.log("[PostDetail][perf] sort done at +" + (Date.now() - rebuildStartMs) + "ms (rebuildReplies-relative)")

        for (var i = 0; i < sorted.length; i++) {
            var chainRows = buildBestReplyChain(sorted[i], 10)
            for (var r = 0; r < chainRows.length; r++)
                threadModel.append(chainRows[r])
        }

        // TEMP DIAGNOSTIC
        //console.log("[PostDetail][perf] all reply chains mapped/appended at +" + (Date.now() - rebuildStartMs) + "ms (rebuildReplies-relative), threadModel.count=" + threadModel.count)

        // Land somewhere on the focus post itself, not just the top of the list

        if (rawAncestors.length > 0)
            focusPositionTimer.restart()
    }

    // Delaying a bit
    Timer {
        id: focusPositionTimer
        interval: 0
        running: false
        repeat: false
        onTriggered: {
            listView.positionViewAtIndex(postDetailPage.focusIndex, ListView.Beginning)
            // try to position so that the header is visible
            listView.contentY = Math.max(0, listView.contentY - Theme.itemSizeLarge)
        }
    }

    // Walks down from a direct reply, at each step following its most-liked child, up to maxDepth rows deep
    function buildBestReplyChain(startNode, maxDepth) {
        var rows = []
        var node = startNode // { post: <status> }

        for (var depth = 0; depth < maxDepth; depth++) {
            var row = PostMapper.mapStatus(node.post, PostMapper.formatTimeAgo)
            row.sectionLabel = qsTr("Replies")
            row.indented = false
            row.isFocusPost = false
            rows.push(row)

            var children = childrenByParent[node.post.id] || []

            if (children.length === 0)
                break // chain ends here - nothing more to follow

            var topChild = children[0]
            for (var k = 1; k < children.length; k++) {
                if ((children[k].favourites_count || 0) > (topChild.favourites_count || 0))
                    topChild = children[k]
            }
            node = { post: topChild }
        }

        // A row only shows a connecting line down to the next one if we
        // actually appended that next row as part of this same chain
        for (var m = 0; m < rows.length; m++) {
            rows[m].hasDisplayedContinuation = (m < rows.length - 1)
        }

        return rows
    }
}
