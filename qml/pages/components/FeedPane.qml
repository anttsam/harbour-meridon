import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib
import "../../lib/SessionManager.js" as SessionManager
import "../../lib/FeedsManager.js" as FeedsManager

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

        FeedsManager.loadFeedContent(feed, reset, contentAnchor, function(success, error401, message, status) {
            busy = false
            if (error401) {
                SessionManager.clearSession()
                pageStack.animatorReplace(Qt.resolvedUrl("../FirstPage.qml"))
            } else if (!success) {
                errorText = qsTr("Couldn't load feed (%1)").arg(message || status)
            }
        })
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
                if (newCount > 0)
                    Notices.show(qsTr("%n new post(s)", "", newCount), Notice.Short, Notice.Top, 0, Theme.itemSizeSmall)
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
        var x = listView.contentX + listView.width / 2
        var probes = [1, Theme.paddingSmall, Theme.paddingLarge, Theme.itemSizeSmall]
        var anchorIndex = -1
        var offset = 0

        for (var i = 0; i < probes.length && anchorIndex < 0; i++) {
            var y = listView.contentY + probes[i]
            var idx = listView.indexAt(x, y)
            if (idx >= 0) {
                anchorIndex = idx
                var item = listView.itemAt(x, y)
                offset = item ? listView.contentY - item.y : 0
            }
        }

        // Nothing under the probes - e.g. overscrolled above the first post
        // while the pull-down menu is still settling. That's "at the top".
        if (anchorIndex < 0) {
            anchorIndex = 0
            offset = 0
        }

        insert()

        listView.positionViewAtIndex(anchorIndex + count, ListView.Beginning)
        listView.contentY += offset

        // That jump isn't a scroll the user made, so don't let the tracker
        // judge their next drag against where contentY used to be - it would
        // read scrolling up toward the new posts as a long scroll down and
        // flash the top bar away.
        scrollTracker.rebase()
    }

    function scrollToTop() {
        listView.scrollToTop()
        scrollTracker.reset()
    }
}
