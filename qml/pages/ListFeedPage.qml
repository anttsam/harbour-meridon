import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager
import "../lib/PostMapper.js" as PostMapper

// Opens a single Mastodon List's timeline as a standalone page

AppPage {
    id: page

    property string listId: ""
    property string listTitle: ""

    allowedOrientations: Orientation.All

    property bool busy: false
    property string errorText: ""
    property string nextCursor: ""
    property string lastLoadMoreCursor: ""

    ListModel {
        id: postsModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: postsModel

        header: PageHeader {
            title: page.listTitle
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: page.load(true)
            }
        }

        function checkLoadMore() {
            if (!page.busy && page.nextCursor.length > 0
                && page.nextCursor !== page.lastLoadMoreCursor && atYEnd) {
                page.lastLoadMoreCursor = page.nextCursor
                page.load(false)
            }
        }
        onAtYEndChanged: checkLoadMore()
        onMovementEnded: checkLoadMore()

        delegate: PostDelegate {}

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: !page.busy && postsModel.count === 0 && errorText.length === 0
            text: qsTr("No posts yet")
            hintText: qsTr("Pull down to refresh")
        }

        ViewPlaceholder {
            enabled: errorText.length > 0 && postsModel.count === 0
            text: qsTr("Couldn't load feed")
            hintText: errorText
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: page.busy && postsModel.count === 0
        visible: running
        size: BusyIndicatorSize.Large
    }

    Component.onCompleted: load(true)

    function load(reset) {
        if (busy)
            return

        busy = true
        if (reset) {
            errorText = ""
            nextCursor = ""
            lastLoadMoreCursor = ""
        }

        var path = "/api/v1/timelines/list/" + encodeURIComponent(page.listId) + "?limit=40"
        if (!reset && nextCursor.length > 0)
            path += "&max_id=" + encodeURIComponent(nextCursor)

        SessionManager.authenticatedRequest("GET", path, null,
            function(response, linkHeader) {
                busy = false
                var statuses = response || []
                nextCursor = PostMapper.parseNextCursor(linkHeader)

                if (reset)
                    postsModel.clear()

                for (var i = 0; i < statuses.length; i++)
                    postsModel.append(PostMapper.mapStatus(statuses[i], PostMapper.formatTimeAgo))
            },
            function(status, message) {
                busy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
                } else {
                    errorText = qsTr("Couldn't load feed (%1)").arg(message || status)
                }
            }
        )
    }
}
