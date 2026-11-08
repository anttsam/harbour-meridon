import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib
import "../../lib/SessionManager.js" as SessionManager
import "../../lib/FeedsManager.js" as FeedsManager
import "../../lib/FeedMarkerPolicy.js" as MarkerPolicy

// One feed's post list

Item {
    id: feedPane

    property var feed

    // To avoid destruction FeedCarouselView.qml passes itself here instead,
    // it's instantiated once and stays alive for the whole session.
    property var contentAnchor

    // Lets a standalone page (e.g. HashtagPage.qml) put its own PageHeader
    property Component pageHeader: null

    property bool busy: false
    property string errorText: ""

    ScrollDirectionTracker {
        id: scrollTracker
        target: listView
    }
    property alias tabBarHidden: scrollTracker.hidden

    readonly property bool isCurrent: !PathView.view || PathView.isCurrentItem

    function checkLoad() {
        var content = FeedsManager.getFeedContent(feed.id, contentAnchor)
        if (isCurrent && !content.loadedOnce && !content.busy)
            load(true)
        else
            checkStale()
    }

    // A list loaded earlier whose Following feed has since got new posts (see
    // FeedsManager.markListsStale()) merge-refreshes once it is on screen.
    function checkStale() {
        var content = FeedsManager.peekFeedContent(feed.id)
        if (isCurrent && content && content.loadedOnce && content.stale && !content.busy && !busy)
            refresh()
    }
    onIsCurrentChanged: checkLoad()
    Component.onCompleted: {
        checkLoad()

        // Lets FeedsManager.refreshFeedContent() keep this list's position
        // whoever triggers the refresh - the menu below, or the cover.
        var content = FeedsManager.peekFeedContent(feed.id)
        if (content) {
            content.positionKeeper = feedPane.keepPositionWhileInserting
            content.keeperOwner = feedPane
        }
    }
    Component.onDestruction: {
        // The carousel recycles panes; don't lose a position still waiting
        // for its debounce.
        if (markerTimer.running) {
            try {
                writeMarker()
            } catch (e) {
                console.warn("[FeedPane] flushing home marker failed:", e)
            }
        }

        var content = FeedsManager.peekFeedContent(feed.id)
        if (content && content.keeperOwner === feedPane) {
            content.positionKeeper = null
            content.keeperOwner = null
        }
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: FeedsManager.getFeedContent(feedPane.feed.id, feedPane.contentAnchor).model
        header: Loader {
            width: listView.width
            sourceComponent: feedPane.pageHeader
        }

        PullDownMenu {
            busy: feedPane.busy
            opacity: active? 1:0 // looks better when hidden
            MenuItem {
                text: qsTr("Refresh")
                onClicked: feedPane.refresh()
            }
        }

        function checkLoadMore() {
            var content = FeedsManager.getFeedContent(feedPane.feed.id, feedPane.contentAnchor)
            if (!feedPane.busy && content.nextCursor.length > 0
                && content.nextCursor !== content.lastLoadMoreCursor && atYEnd) {
                content.lastLoadMoreCursor = content.nextCursor
                feedPane.load(false)
            }
        }
        onAtYEndChanged: checkLoadMore()
        onMovementEnded: checkLoadMore()

        delegate: PostDelegate {}

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: !feedPane.busy && listView.count === 0 && feedPane.errorText.length === 0
            text: qsTr("No posts yet")
            hintText: qsTr("Pull down to refresh or add content")
        }

        ViewPlaceholder {
            enabled: feedPane.errorText.length > 0 && listView.count === 0
            text: qsTr("Couldn't load feed")
            hintText: feedPane.errorText
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: feedPane.busy && listView.count === 0
        visible: running
        size: BusyIndicatorSize.Large
    }

    BusyIndicator {
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: Theme.paddingMedium
        }
        running: feedPane.busy && listView.count > 0
        visible: running
        size: BusyIndicatorSize.Small
    }

    function load(reset) {
        if (busy && !reset)
            return

        busy = true
        if (reset)
            errorText = ""

        var done = function(success, error401, message, status, landingIndex) {
            busy = false
            if (error401) {
                SessionManager.clearSession()
                pageStack.animatorReplace(Qt.resolvedUrl("../FirstPage.qml"))
            } else if (!success) {
                errorText = qsTr("Couldn't load feed (%1)").arg(message || status)
            } else if (landingIndex !== undefined) {
                showLanding(landingIndex)
            }
        }

        // The first load of the home feed, or of a list (a filtered view of
        // it), in this app run reopens where the user stopped reading in
        // Following (see FeedsManager.loadFeedAtMarker()).
        var content = FeedsManager.getFeedContent(feed.id, contentAnchor)
        if (reset && !content.loadedOnce && MarkerPolicy.usesFollowingMarker(feed))
            FeedsManager.loadFeedAtMarker(feed, contentAnchor, done)
        else
            FeedsManager.loadFeedContent(feed, reset, contentAnchor, done)
    }

    // Scrolls the freshly loaded home feed so row `index` is at the top, the
    // posts above it being the ones that arrived since the user last read.
    // The view is positioned straight away and once more on the next event
    // loop turn, in case it had not laid out the new rows yet.
    property int landingIndex: -1

    function showLanding(index) {
        markPositionProgrammatic()
        if (index <= 0)
            return

        landingIndex = index
        applyLanding()
        landingTimer.restart()

        if (index === 1)
            Notices.show(qsTr("%n new post", "", index), Notice.Short, Notice.Top, 0, Theme.itemSizeSmall)
        else
            Notices.show(qsTr("%n new posts", "", index), Notice.Short, Notice.Top, 0, Theme.itemSizeSmall)
    }

    function applyLanding() {
        if (landingIndex < 0)
            return

        listView.positionViewAtIndex(landingIndex, ListView.Beginning)
        scrollTracker.rebase()
        markPositionProgrammatic()
    }

    Timer {
        id: landingTimer
        interval: 0
        repeat: false
        onTriggered: {
            feedPane.applyLanding()
            feedPane.landingIndex = -1
        }
    }

    // Pull-to-refresh: merges new posts in at the top and updates the loaded
    // ones in place, keeping the scroll position (see
    // FeedsManager.refreshFeedContent()) - load(true) stays the full reload.
    function refresh() {
        if (busy)
            return

        busy = true
        errorText = ""

        FeedsManager.refreshFeedContent(feed, contentAnchor, function(success, error401, message, status, newCount) {
            busy = false
            if (error401) {
                SessionManager.clearSession()
                pageStack.animatorReplace(Qt.resolvedUrl("../FirstPage.qml"))
            } else if (!success) {
                errorText = qsTr("Couldn't load feed (%1)").arg(message || status)
            } else {
                AppLib.TimeManager.bump()

                // The list keeps showing what you were reading, so say
                // something new is waiting above it. Offset to sit under the
                // tab strip rather than over the feed names.
                if (newCount === 1)
                    Notices.show(qsTr("%n new post", "", newCount), Notice.Short, Notice.Top, 0, Theme.itemSizeSmall)
                else if (newCount > 1)
                    Notices.show(qsTr("%n new posts", "", newCount), Notice.Short, Notice.Top, 0, Theme.itemSizeSmall)
            }
        })
    }

    // Registered with the feed's content bucket (see Component.onCompleted),
    // called by FeedsManager.refreshFeedContent() with the number of posts
    // about to be inserted above everything already loaded, and insert() to
    // do it. The refresh menu is only reachable with the list at the very
    // top, and there ListView treats an insert at index 0 as "show the new
    // item", so without this the view stays put and the new post pushes what
    // you were reading down. Remember which post is first on screen and how
    // far into it we are, insert, then put that same post back where it was
    // - the new posts end up above, reachable by scrolling up.
    function keepPositionWhileInserting(count, insert) {
        var top = topVisible()

        insert()

        listView.positionViewAtIndex(top.index + count, ListView.Beginning)
        listView.contentY += top.offset

        // That jump isn't a scroll the user made, so don't let the tracker
        // judge their next drag against where contentY used to be - it would
        // read scrolling up toward the new posts as a long scroll down and
        // flash the top bar away.
        scrollTracker.rebase()
        markPositionProgrammatic()
    }

    // The post at the top of the view: its index in the model, and how far
    // into it the view is scrolled.
    function topVisible() {
        var x = listView.contentX + listView.width / 2
        var probes = [1, Theme.paddingSmall, Theme.paddingLarge, Theme.itemSizeSmall]
        var index = -1
        var offset = 0

        for (var i = 0; i < probes.length && index < 0; i++) {
            var y = listView.contentY + probes[i]
            var idx = listView.indexAt(x, y)
            if (idx >= 0) {
                index = idx
                var item = listView.itemAt(x, y)
                offset = item ? listView.contentY - item.y : 0
            }
        }

        // Nothing under the probes - e.g. overscrolled above the first post
        // while the pull-down menu is still settling. That's "at the top".
        if (index < 0) {
            index = 0
            offset = 0
        }

        return { index: index, offset: offset }
    }

    // Reading position (home feed only - the only timeline Mastodon's
    // markers cover): the newest post the user has had at the top of the
    // list is written as the server-side "home" marker once they have
    // stopped scrolling, and when the app goes to the background, so a later
    // cold start can reopen there with everything newer above it. It only
    // moves to newer posts - scrolling down through older ones never lowers
    // it. See docs/feed-position-markers-spec.md.
    //
    // Only a scroll the user made counts (userMoved, set by dragging). Moves
    // made by code - the tap-to-top below, the position kept across an insert
    // - clear it, so just opening the app, or being jumped around by it, can
    // never overwrite where the user actually stopped reading.
    property bool userMoved: false
    property string newestSeenId: ""

    // Called when a drag starts (the view the user was looking at before
    // moving it, e.g. the newest posts at the top of a fresh feed) and when
    // movement ends.
    function noteSeen() {
        if (feed.type !== "home")
            return

        var content = FeedsManager.peekFeedContent(feed.id)
        if (!content || listView.count === 0)
            return

        var row = content.model.get(topVisible().index)
        if (row && MarkerPolicy.compareIds(row.timelineId, newestSeenId) > 0)
            newestSeenId = row.timelineId
    }

    function markPositionProgrammatic() {
        userMoved = false
        markerTimer.stop()
    }

    function writeMarker() {
        markerTimer.stop()
        if (feed.type !== "home" || newestSeenId.length === 0)
            return

        var content = FeedsManager.peekFeedContent(feed.id)
        if (!content)
            return

        if (MarkerPolicy.shouldWrite(newestSeenId, content.lastMarkerId, userMoved, content.restoring))
            FeedsManager.saveMarker(content, newestSeenId)
    }

    Timer {
        id: markerTimer
        interval: MarkerPolicy.WRITE_DEBOUNCE_MS
        repeat: false
        onTriggered: feedPane.writeMarker()
    }

    Connections {
        target: listView
        onDraggingChanged: {
            if (listView.dragging) {
                feedPane.noteSeen()
                feedPane.userMoved = true
            }
        }
        onMovementEnded: {
            if (feedPane.userMoved && feedPane.feed.type === "home") {
                feedPane.noteSeen()
                markerTimer.restart()
            }
        }
    }

    Connections {
        target: Qt.application
        onActiveChanged: {
            if (!Qt.application.active)
                feedPane.writeMarker()
            else
                feedPane.checkStale()
        }
    }

    function scrollToTop() {
        markPositionProgrammatic()
        listView.scrollToTop()
        scrollTracker.reset()
    }
}
