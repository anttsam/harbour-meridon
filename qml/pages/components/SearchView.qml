import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib/SessionManager.js" as SessionManager
import "../../lib/PostMapper.js" as PostMapper
import "../../lib" as AppLib

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
    property bool textInputAvailable: false
    property real sizeMultiplier: AppLib.FontManager.fontSizeMultiplier

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
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: searchPanel.visibleSize
        model: searchView.searched ? resultsModel : trendingModel
        delegate: PostDelegate {}

        clip: true

        header: PageHeader {
            title: searchView.searched ? searchView.queryText : "Trending"
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: searchView.searched ? searchView.runSearch(true) : searchView.loadTrending()
            }
            //opacity: active ? 1 : 0
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

    MouseArea {
        anchors.fill: parent
        enabled: searchField.focus
        onClicked: searchField.focus = false
    }
    MouseArea {
        anchors.fill: parent
        enabled: searchContextMenu.active
        onClicked: searchContextMenu.close(header)
    }

    Item {
        id: searchPanel
        width: parent.width
        height: header.height
        anchors.bottom: parent.bottom

        // Deliberately not DockedPanel here as it will not stack with main panel animation
        property real hiddenOffset: scrollTracker.hidden ? height : 0
        Behavior on hiddenOffset {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }
        anchors.bottomMargin: -hiddenOffset
        readonly property real visibleSize: height - hiddenOffset

        Rectangle {
            anchors.fill: parent
            color: Theme.darkPrimaryColor
            opacity: 0.1
            border.color: AppLib.BackgroundManager.activeHighlightColor
            border.width: Theme.paddingSmall / 2
        }

        Rectangle {
            id: header
            width: parent.width
            anchors.top: parent.top
            height: textInputAvailable ? searchField.height + searchContextMenu.height : searchField.height
            color: "transparent"

            // Animating here searchPanel.height for closing
            Behavior on height {
                enabled: !textInputAvailable
                NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
            }

            // flag so that only commit/navigate away drop the field's focus.
            property bool searchCommitting: false


            ContextMenu {
                id: searchContextMenu
                enabled: textInputAvailable
                _closeOnOutsideClick: false
                clip: true
                MenuItem {
                    text: "Go to #"+ searchView.queryText
                    onClicked: {
                        header.searchCommitting = true
                        pageStack.push(Qt.resolvedUrl("../HashtagPage.qml"), { hashtag: searchView.queryText })
                    }
                    font.family: AppLib.FontManager.activeFontFamily
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                }
                MenuItem {
                    text: "Go to @"+ searchView.queryText
                    onClicked: {
                        header.searchCommitting = true
                        searchContextMenu.close(header)
                        searchField.focus = false
                        searchView.goToAccount(searchView.queryText)
                    }
                    font.family: AppLib.FontManager.activeFontFamily
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                }
                MenuItem {
                    text: "Posts matching '"+ searchView.queryText + "'"
                    onClicked: {
                        header.searchCommitting = true
                        searchContextMenu.close(header)
                        searchView.runSearch(true)
                        focus = false
                    }
                    font.family: AppLib.FontManager.activeFontFamily
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                }
                MenuItem {
                    text: "People matching '"+ searchView.queryText + "'"
                    onClicked: {
                        header.searchCommitting = true
                        searchContextMenu.close(header)
                        searchField.focus = false
                        pageStack.push(Qt.resolvedUrl("../PeopleSearchPage.qml"), { query: searchView.queryText })
                    }
                    font.family: AppLib.FontManager.activeFontFamily
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                }
                onActiveChanged: {
                    if (!active) {
                        if (header.searchCommitting)
                            searchField.focus = false
                        header.searchCommitting = false
                    }
                }
            }
            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search")
                EnterKey.iconSource: "image://theme/icon-m-enter-search"
                EnterKey.onClicked: {
                    header.searchCommitting = true
                    searchContextMenu.close(header)
                    searchView.runSearch(true)
                    focus = false
                }
                onTextChanged: {
                    searchView.queryText = text
                    if (text.trim().length === 0 && searchView.searched) {
                        searchView.searched = false
                        searchView.errorText = ""
                    }
                    if (text.trim().length !== 0) {
                        textInputAvailable = true
                        searchContextMenu.open(header)
                    } else {
                        textInputAvailable = false
                        searchContextMenu.close(header)
                    }
                }
                onFocusChanged: if  (focus && text.trim().length !== 0) { searchContextMenu.open(header) } //else { searchContextMenu.close(header) }
            }
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

    // "Go to @handle" - resolve=true lets the instance do a WebFinger
    // lookup for accounts it doesn't know about yet, same as
    // LinkHandler.js's resolveProfileLink() for @mentions in post bodies.
    function goToAccount(handle) {
        var q = handle.trim()
        if (q.length === 0)
            return

        SessionManager.authenticatedRequest("GET",
            "/api/v2/search?q=" + encodeURIComponent(q) + "&type=accounts&resolve=true&limit=1", null,
            function(response) {
                var accounts = (response && response.accounts) || []
                if (accounts.length > 0) {
                    pageStack.push(Qt.resolvedUrl("../UserProfilePage.qml"), { did: accounts[0].id })
                } else {
                    pageStack.push(Qt.resolvedUrl("../UserProfilePage.qml"), { unresolvedHandle: q })
                }
            },
            function(status, message) {
                console.warn("[Search] account resolve failed:", status, message)
                pageStack.push(Qt.resolvedUrl("../UserProfilePage.qml"), { unresolvedHandle: q })
            }
        )
    }

    function scrollToTop() { //for tabbar button
        listView.scrollToTop()
        scrollTracker.reset()
    }
}
