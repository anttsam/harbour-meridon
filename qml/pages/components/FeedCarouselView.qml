import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib/FeedsManager.js" as FeedsManager
import "../../lib/VideoExpansionTracker.js" as VideoExpansionTracker

// Home tab root: a compact feed-name strip (FeedTabStrip)

Item {
    id: feedCarouselView

    property bool isPortrait: true

    property bool feedsReady: false

    ListModel {
        id: feedsModel
    }

    function feedRow(feed) {
        // Every real-feed row appended to feedsModel goes through here
        return {
            id: feed.id,
            type: feed.type,
            value: feed.value,
            displayName: feed.displayName,
            avatarUrl: feed.avatarUrl || "",
            pinned: feed.pinned === true
        }
    }

    function moreRow() {
        return {
            id: "__more__",
            type: "more",
            value: "",
            displayName: qsTr("More"),
            avatarUrl: "",
            pinned: false
        }
    }

    function indexOfType(type) {
        for (var i = 0; i < feedsModel.count; i++) {
            if (feedsModel.get(i).type === type)
                return i
        }
        return -1
    }

    function indexOfId(id) {
        for (var i = 0; i < feedsModel.count; i++) {
            if (feedsModel.get(i).id === id)
                return i
        }
        return -1
    }

    function feedFromRow(row) {
        return {
            id: row.id,
            type: row.type,
            value: row.value,
            displayName: row.displayName,
            avatarUrl: row.avatarUrl,
            pinned: row.pinned
        }
    }

    function populateFeeds() {
        // remmember which feed, instead of unconditionally bounce them back to Home.
        var wasPopulatedBefore = feedsReady
        var previousFeedId = (wasPopulatedBefore && feedsModel.count > 0 && slideshow.currentIndex >= 0)
            ? feedsModel.get(slideshow.currentIndex).id : ""

        feedsModel.clear()
        var saved = FeedsManager.getFeeds()
        for (var i = 0; i < saved.length; i++)
            feedsModel.append(feedRow(saved[i]))
        feedsModel.append(moreRow())

        feedsReady = true

        var startIndex = -1

        // On a refresh, stay on the same feed if it still exists
        if (wasPopulatedBefore && previousFeedId.length > 0)
            startIndex = indexOfId(previousFeedId)

        if (startIndex < 0) {
            // First-ever population (cold start)
            var homeIdx = indexOfType("home")
            startIndex = homeIdx >= 0 ? homeIdx : 0
        }

        tabStrip.currentIndex = startIndex
        slideshow.currentIndex = startIndex
    }

    function scrollToTop() {
        if (slideshow.currentItem)
            slideshow.currentItem.scrollToTop()

        // Explicit snow
        tabStripPanel.show()
    }

    property bool tabBarHidden: false

    property bool stripHidden: false

    Connections {
        target: slideshow.currentItem
        ignoreUnknownSignals: true
        onTabBarHiddenChanged: {
            feedCarouselView.tabBarHidden = slideshow.currentItem.tabBarHidden
            feedCarouselView.stripHidden = slideshow.currentItem.tabBarHidden
        }
    }

    property bool anyVideoExpanded: false
    readonly property bool topStripShouldShow: !anyVideoExpanded && !stripHidden

    onTopStripShouldShowChanged: {
        if (topStripShouldShow)
            tabStripPanel.show()
        else
            tabStripPanel.hide()
    }

    function refreshFeeds() {
        FeedsManager.loadFeeds(function(success) {
            populateFeeds()
        })
    }

    // Deferring
    Timer {
        id: initialLoadTimer
        interval: 0
        running: false
        repeat: false
        onTriggered: {
            if (FeedsManager.isLoaded()) {
                populateFeeds()
            } else {
                FeedsManager.loadFeeds(function(success) {
                    populateFeeds() // FeedsManager still falls back to a Home-only list either way
                })
            }
        }
    }

    Component.onCompleted: {
        initialLoadTimer.start()

        VideoExpansionTracker.subscribe(function(expanded) {
            feedCarouselView.anyVideoExpanded = expanded
        })

        FeedsManager.setDirtyListener(function() {
            feedCarouselView.refreshFeeds()
        })
        // Explicit initial call
        if (topStripShouldShow)
            tabStripPanel.show()
        else
            tabStripPanel.hide()
    }

    SlideshowView {
        id: slideshow
        anchors {
            top: parent.top
            topMargin: tabStripPanel.visibleSize
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        model: feedsModel

        delegate: Item {
            id: slideDelegate
            width: slideshow.width
            height: slideshow.height

            function scrollToTop() {
                if (loader.item && loader.item.scrollToTop)
                    loader.item.scrollToTop()
            }

            readonly property bool tabBarHidden: loader.item ? loader.item.tabBarHidden : false

            Loader {
                id: loader
                anchors.fill: parent
                sourceComponent: model.type === "more" ? moreSlideComponent : feedPaneComponent
            }

            Component {
                id: feedPaneComponent
                FeedPane {
                    feed: feedCarouselView.feedFromRow(model)
                    // Must outlive this delegate, see feedpane
                    contentAnchor: feedCarouselView
                }
            }

            Component {
                id: moreSlideComponent
                MoreSlide {}
            }
        }

        onCurrentIndexChanged: {
            if (tabStrip.currentIndex !== currentIndex)
                tabStrip.currentIndex = currentIndex

            feedCarouselView.stripHidden = false
            tabStripPanel.show()

            if (currentIndex >= 0 && currentIndex < feedsModel.count) {
                var row = feedsModel.get(currentIndex)
                if (row.type !== "more")
                    FeedsManager.setCurrentFeed(feedCarouselView.feedFromRow(row))
            }
        }
    }


    DockedPanel {
        id: tabStripPanel
        width: parent.width
        height: tabStrip.height
        dock: Dock.Top
        open: true
        background: null

        FeedTabStrip {
            id: tabStrip
            width: parent.width
            isPortrait: feedCarouselView.isPortrait
            model: feedsModel
            onCurrentIndexChanged: {
                if (slideshow.currentIndex !== currentIndex)
                    slideshow.currentIndex = currentIndex
            }
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: !feedCarouselView.feedsReady
        visible: running
        size: BusyIndicatorSize.Large
    }

}
