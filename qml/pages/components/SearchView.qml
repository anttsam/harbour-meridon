import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib/SessionManager.js" as SessionManager
import "../../lib/PostMapper.js" as PostMapper

Item {
    id: searchView

    Component.onCompleted: loadTrending()

    property bool busy: false
    property string errorText: ""
    // signal last
    property bool hasMore: true

    // fire only once...
    property int lastLoadMoreCount: -1

    property string queryText: ""

    // true once the user has actually submitted a search - until then the
    // list shows the trending-posts feed as a placeholder, per the Mastodon
    // apps' "Posts" explore tab (GET /api/v1/trends/statuses).
    property bool searched: false

    ScrollDirectionTracker {
        id: scrollTracker
        target: listView
    }
    property alias tabBarHidden: scrollTracker.hidden

    ListModel {
        id: resultsModel
    }

    ListModel {
        id: trendingModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: searchView.searched ? resultsModel : trendingModel

        header: Column {
            width: parent.width

            PageHeader {
                title: qsTr("Search")
            }

            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search posts")
                EnterKey.iconSource: "image://theme/icon-m-enter-search"
                EnterKey.onClicked: searchView.runSearch(true)
                onTextChanged: {
                    searchView.queryText = text
                    if (text.trim().length === 0 && searchView.searched) {
                        searchView.searched = false
                        searchView.errorText = ""
                    }
                }
            }
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: searchView.searched ? searchView.runSearch(true) : searchView.loadTrending()
            }
        }

        function checkLoadMore() {
            if (!busy && searchView.hasMore && queryText.trim().length > 0
                && resultsModel.count !== lastLoadMoreCount && atYEnd) {
                lastLoadMoreCount = resultsModel.count
                searchView.runSearch(false)
            }
        }
        onAtYEndChanged: checkLoadMore()
        onMovementEnded: checkLoadMore()

        delegate: PostDelegate {}

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: !searchView.busy && errorText.length === 0
                && (searchView.searched ? resultsModel.count === 0 : trendingModel.count === 0)
            text: searchView.searched ? qsTr("No results") : qsTr("Nothing trending")
            hintText: searchView.searched ? qsTr("Try a different search term") : qsTr("Check back later")
        }

        ViewPlaceholder {
            enabled: errorText.length > 0
            text: searchView.searched ? qsTr("Search failed") : qsTr("Couldn't load trending posts")
            hintText: errorText
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: searchView.busy
        visible: running
        size: BusyIndicatorSize.Large
    }

    function loadTrending() {
        if (busy)
            return

        busy = true
        errorText = ""

        SessionManager.authenticatedRequest("GET", "/api/v1/trends/statuses?limit=20", null,
            function(response) {
                busy = false

                var statuses = response || []
                trendingModel.clear()
                for (var i = 0; i < statuses.length; i++) {
                    trendingModel.append(PostMapper.mapStatus(statuses[i], PostMapper.formatTimeAgo))
                }
            },
            function(status, message) {
                busy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("../FirstPage.qml"))
                } else {
                    errorText = qsTr("Couldn't load trending posts (%1)").arg(message || status)
                }
            }
        )
    }

    function runSearch(reset) {
        var query = queryText.trim()
        if (query.length === 0 || busy)
            return

        searched = true
        busy = true
        if (reset) {
            errorText = ""
            hasMore = true
            lastLoadMoreCount = -1
            resultsModel.clear()
        }

        var path = "/api/v2/search?q=" + encodeURIComponent(query)
            + "&type=statuses&limit=30&offset=" + resultsModel.count

        console.log("[Search] querying:", query,
            reset ? "(new search)" : "(load more)")

        SessionManager.authenticatedRequest("GET", path, null,
            function(response) {
                busy = false

                var statuses = (response && response.statuses) || []
                console.log("[Search] got", statuses.length, "results")

                for (var i = 0; i < statuses.length; i++) {
                    resultsModel.append(PostMapper.mapStatus(statuses[i], PostMapper.formatTimeAgo))
                }

                hasMore = statuses.length > 0
            },
            function(status, message) {
                busy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("../FirstPage.qml"))
                } else {
                    errorText = qsTr("Couldn't search (%1)").arg(message || status)
                }
            }
        )
    }

    function scrollToTop() {
        listView.scrollToTop()
        scrollTracker.reset()
    }
}
