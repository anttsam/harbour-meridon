import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager
import "../lib/FeedsManager.js" as FeedsManager
import "../lib/PostMapper.js" as PostMapper

AppPage {
    id: page

    property string hashtag: ""
    property bool following: false
    property bool followBusy: false

    property bool busy: false
    property string errorText: ""
    property string nextCursor: ""
    property string lastLoadMoreCursor: ""

    allowedOrientations: Orientation.All

    ListModel {
        id: postsModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: postsModel

        header: Column {
            width: parent.width

            PageHeader {
                title: "#" + page.hashtag
            }

            Item {
                width: parent.width
                height: followButton.height + Theme.paddingMedium

                Button {
                    id: followButton
                    anchors {
                        right: parent.right
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    preferredWidth: Theme.buttonWidthMedium
                    enabled: !page.followBusy
                    text: page.following ? qsTr("Following") : qsTr("Follow")
                    onClicked: page.toggleFollow()
                }
            }
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

    Component.onCompleted: {
        loadFollowState()
        load(true)
    }

    function load(reset) {
        if (busy)
            return

        busy = true
        if (reset) {
            errorText = ""
            nextCursor = ""
            lastLoadMoreCursor = ""
        }

        var path = "/api/v1/timelines/tag/" + encodeURIComponent(page.hashtag) + "?limit=40"
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

    function loadFollowState() {
        SessionManager.authenticatedRequest("GET",
            "/api/v1/tags/" + encodeURIComponent(page.hashtag), null,
            function(response) {
                page.following = !!(response && response.following)
            },
            function(status, message) {
                console.warn("[Hashtag] couldn't load follow state:", status, message)
            }
        )
    }

    function toggleFollow() {
        if (page.followBusy)
            return
        page.followBusy = true

        var action = page.following ? "unfollow" : "follow"
        SessionManager.authenticatedRequest("POST",
            "/api/v1/tags/" + encodeURIComponent(page.hashtag) + "/" + action, {},
            function(response) {
                page.followBusy = false
                page.following = !!(response && response.following)
                // Tells MainPage.qml to refresh the Home carousel next time
                FeedsManager.markDirty()
            },
            function(status, message) {
                page.followBusy = false
                console.warn("[Hashtag]", action, "failed:", status, message)
            }
        )
    }
}
