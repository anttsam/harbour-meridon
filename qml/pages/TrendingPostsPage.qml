import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager
import "../lib/PostMapper.js" as PostMapper

// Mastodon's GET /api/v1/trends/statuses - posts with the most engagement

AppPage {
    id: page

    property bool busy: false
    property string errorText: ""
    property bool hasMore: true

    // fire only once...
    property int lastLoadMoreCount: -1

    ListModel {
        id: postsModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: postsModel

        header: PageHeader {
            title: qsTr("Trending Posts")
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: page.load(true)
            }
        }

        function checkLoadMore() {
            if (!page.busy && page.hasMore
                && postsModel.count !== page.lastLoadMoreCount && atYEnd) {
                page.lastLoadMoreCount = postsModel.count
                page.load(false)
            }
        }
        onAtYEndChanged: checkLoadMore()
        onMovementEnded: checkLoadMore()

        delegate: PostDelegate {}

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: !page.busy && postsModel.count === 0 && errorText.length === 0
            text: qsTr("Nothing trending")
            hintText: qsTr("Check back later")
        }

        ViewPlaceholder {
            enabled: errorText.length > 0 && postsModel.count === 0
            text: qsTr("Couldn't load")
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
            hasMore = true
            lastLoadMoreCount = -1
            postsModel.clear()
        }

        var path = "/api/v1/trends/statuses?limit=20&offset=" + postsModel.count

        SessionManager.authenticatedRequest("GET", path, null,
            function(response) {
                busy = false
                var statuses = response || []
                for (var i = 0; i < statuses.length; i++)
                    postsModel.append(PostMapper.mapStatus(statuses[i], PostMapper.formatTimeAgo))
                hasMore = statuses.length > 0
            },
            function(status, message) {
                busy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
                } else {
                    errorText = qsTr("Couldn't load trending posts (%1)").arg(message || status)
                }
            }
        )
    }
}
