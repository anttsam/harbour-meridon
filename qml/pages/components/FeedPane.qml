import QtQuick 2.0
import Sailfish.Silica 1.0
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
    Component.onCompleted: checkLoad()

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
                onClicked: feedPane.load(true)
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

    function scrollToTop() {
        listView.scrollToTop()
        scrollTracker.reset()
    }
}
