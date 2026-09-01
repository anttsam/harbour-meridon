import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib
import "../../lib/SessionManager.js" as SessionManager
import "../../lib/PostMapper.js" as PostMapper

Item {
    id: notificationsView

    property bool busy: false
    property string errorText: ""
    property string nextCursor: ""

    property string lastLoadMoreCursor: ""

    ScrollDirectionTracker {
        id: scrollTracker
        target: listView
    }
    property alias tabBarHidden: scrollTracker.hidden

    ListModel {
        id: notificationsModel
    }

    function reasonLabel(reason) {
        switch (reason) {
        case "favourite": return qsTr("favourited your post")
        case "reblog": return qsTr("boosted your post")
        case "follow": return qsTr("followed you")
        case "follow_request": return qsTr("requested to follow you")
        case "mention": return qsTr("mentioned you")
        case "status": return qsTr("posted")
        case "poll": return qsTr("poll you voted in has ended")
        case "update": return qsTr("edited a post you interacted with")
        default: return reason
        }
    }

    function reasonIcon(reason) {
        switch (reason) {
        case "favourite": return "image://theme/icon-s-like"
        case "reblog": return "image://theme/icon-s-retweet"
        case "follow":
        case "follow_request": return "image://theme/icon-m-media-artists"
        default: return "image://theme/icon-s-chat"
        }
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: notificationsModel

        header: PageHeader {
            title: qsTr("Notifications")
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: notificationsView.load(true)
            }
        }

        function checkLoadMore() {
            if (!busy && nextCursor.length > 0 && nextCursor !== lastLoadMoreCursor && atYEnd) {
                lastLoadMoreCursor = nextCursor
                notificationsView.load(false)
            }
        }
        onAtYEndChanged: checkLoadMore()
        onMovementEnded: checkLoadMore()

        delegate: ListItem {
            id: notifDelegate
            contentHeight: mainColumn.height + 2 * Theme.paddingMedium
            onClicked: {
                if (model.statusId && model.statusId.length > 0) {
                    pageStack.push(Qt.resolvedUrl("../PostDetailPage.qml"), {
                        postUri: model.statusId
                    })
                } else if (model.accountId && model.accountId.length > 0) {
                    pageStack.push(Qt.resolvedUrl("../UserProfilePage.qml"), {
                        did: model.accountId
                    })
                }
            }

            Column {
                id: mainColumn
                x: Theme.horizontalPageMargin
                y: Theme.paddingMedium
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                Item {
                    id: icoRow
                    width: parent.width
                    height: avatar.height

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.paddingMedium

                        Image {
                            width: Theme.iconSizeMedium
                            height: Theme.iconSizeMedium
                            source: notificationsView.reasonIcon(model.reason)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        RoundedAvatar {
                            id: avatar
                            size: Theme.iconSizeMedium
                            source: model.avatarUrl

                            MouseArea {
                                anchors.fill: parent
                                onClicked: pageStack.push(Qt.resolvedUrl("../UserProfilePage.qml"), {
                                    did: model.accountId
                                })
                            }
                        }
                    }

                    // "follow" notifications show a Follow back button
                    SecondaryButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        preferredWidth: Theme.buttonWidthExtraSmall
                        visible: model.reason === "follow"
                        text: model.viewerFollowing ? qsTr("Following") : qsTr("Follow back")
                        color: model.viewerFollowing
                            ? Theme.secondaryColor : palette.secondaryHighlightColor
                        onClicked: notificationsView.toggleFollow(index)
                    }

                    // "follow_request" shows Approve/Reject instead
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: model.reason === "follow_request"
                        spacing: Theme.paddingSmall

                        IconButton {
                            icon.source: "image://theme/icon-m-dismiss"
                            onClicked: notificationsView.rejectFollowRequest(index)
                        }
                        IconButton {
                            icon.source: "image://theme/icon-m-enter-accept"
                            onClicked: notificationsView.authorizeFollowRequest(index)
                        }
                    }
                }
                Item {
                    anchors.left:  parent.left
                    anchors.leftMargin: Theme.iconSizeMedium + Theme.paddingMedium
                    anchors.right: parent.right
                    height: textLabel.height
                    AppLabel {
                        id: textLabel
                        text: AppLib.EmojiManager.render(model.displayName || model.handle, model.emojisJson, (Theme.fontSizeSmall) * sizeMultiplier) + " " + notificationsView.reasonLabel(model.reason)
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                        color: model.isRead ? Theme.secondaryColor : Theme.primaryColor
                        width: parent.width - agoLabel.width
                        useCustomFont: true
                    }
                    AppLabel {
                        id: agoLabel
                        text: model.timeAgo
                        font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                        color: Theme.secondaryColor
                        anchors.right: parent.right
                        useCustomFont: true
                        opacity: 0.6
                    }

                }
            }
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: !notificationsView.busy && notificationsModel.count === 0 && errorText.length === 0
            text: qsTr("No notifications")
        }

        ViewPlaceholder {
            enabled: errorText.length > 0 && notificationsModel.count === 0
            text: qsTr("Couldn't load notifications")
            hintText: errorText
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: notificationsView.busy && notificationsModel.count === 0
        visible: running
        size: BusyIndicatorSize.Large
    }

    // Staggered slightly as well
    Timer {
        id: startupLoadTimer
        interval: 400
        running: true
        repeat: false
        onTriggered: notificationsView.load(true)
    }

    function load(reset) {
        if (busy)
            return

        busy = true
        if (reset) {
            errorText = ""
            lastLoadMoreCursor = ""
        }

        var path = "/api/v1/notifications?limit=30"
        if (!reset && nextCursor.length > 0)
            path += "&max_id=" + encodeURIComponent(nextCursor)

        console.log("[Notifications] fetching", reset ? "(refresh)" : "(load more)")

        SessionManager.authenticatedRequest("GET", path, null,
            function(response, linkHeader) {
                if (reset)
                    notificationsModel.clear()

                var notifs = response || []
                console.log("[Notifications] got", notifs.length)
                nextCursor = PostMapper.parseNextCursor(linkHeader)

                var followerIds = []
                for (var i = 0; i < notifs.length; i++) {
                    if (notifs[i].type === "follow" && notifs[i].account)
                        followerIds.push(notifs[i].account.id)
                }

                if (followerIds.length === 0) {
                    busy = false
                    appendNotifications(notifs, null)
                    return
                }

                var relQuery = followerIds.map(function(id) {
                    return "id[]=" + encodeURIComponent(id)
                }).join("&")

                SessionManager.authenticatedRequest("GET",
                    "/api/v1/accounts/relationships?" + relQuery, null,
                    function(relResponse) {
                        busy = false
                        var followingById = {}
                        var rels = relResponse || []
                        for (var r = 0; r < rels.length; r++)
                            followingById[rels[r].id] = !!rels[r].following
                        appendNotifications(notifs, followingById)
                    },
                    function(status, message) {
                        busy = false
                        console.warn("[Notifications] relationships lookup failed:", status, message)
                        appendNotifications(notifs, null)
                    }
                )
            },
            function(status, message) {
                busy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("../FirstPage.qml"))
                } else {
                    errorText = qsTr("Couldn't load notifications (%1)").arg(message || status)
                }
            }
        )
    }

    function appendNotifications(notifs, followingById) {
        for (var i = 0; i < notifs.length; i++) {
            var n = notifs[i]
            notificationsModel.append({
                reason: n.type,
                displayName: (n.account && n.account.display_name) || "",
                emojisJson: PostMapper.emojiMapJson(n.account && n.account.emojis),
                handle: n.account ? n.account.acct : "",
                accountId: n.account ? n.account.id : "",
                avatarUrl: (n.account && n.account.avatar) || "",
                // mastodon API doesn't have read status, so all false
                isRead: false,
                timeAgo: formatTimeAgo(n.created_at),
                statusId: n.status ? n.status.id : "",
                viewerFollowing: (followingById && n.account) ? (followingById[n.account.id] === true) : false
            })
        }
    }

    // optimistic-toggle pattern, same as FollowListPage.qml/SuggestedAccountsPage.qml
    function toggleFollow(index) {
        var item = notificationsModel.get(index)
        if (!item || !item.accountId)
            return

        var wasFollowing = item.viewerFollowing
        var action = wasFollowing ? "unfollow" : "follow"
        notificationsModel.setProperty(index, "viewerFollowing", !wasFollowing)

        SessionManager.authenticatedRequest("POST",
            "/api/v1/accounts/" + encodeURIComponent(item.accountId) + "/" + action, {},
            function(response) {
                notificationsModel.setProperty(index, "viewerFollowing", !!response.following)
            },
            function(status, message) {
                console.warn("[Notifications]", action, "failed:", status, message)
                notificationsModel.setProperty(index, "viewerFollowing", wasFollowing)
            }
        )
    }

    // Resolves the pending request, so the row no longer makes sense to
    // show afterward - removed on success rather than optimistically
    function authorizeFollowRequest(index) {
        var item = notificationsModel.get(index)
        if (!item || !item.accountId)
            return

        SessionManager.authenticatedRequest("POST",
            "/api/v1/follow_requests/" + encodeURIComponent(item.accountId) + "/authorize", {},
            function(response) {
                notificationsModel.remove(index)
            },
            function(status, message) {
                console.warn("[Notifications] authorize follow request failed:", status, message)
            }
        )
    }

    function rejectFollowRequest(index) {
        var item = notificationsModel.get(index)
        if (!item || !item.accountId)
            return

        SessionManager.authenticatedRequest("POST",
            "/api/v1/follow_requests/" + encodeURIComponent(item.accountId) + "/reject", {},
            function(response) {
                notificationsModel.remove(index)
            },
            function(status, message) {
                console.warn("[Notifications] reject follow request failed:", status, message)
            }
        )
    }

    function formatTimeAgo(isoString) {
        var then = new Date(isoString)
        var seconds = Math.floor((new Date() - then) / 1000)

        if (seconds < 60) return qsTr("now")
        var minutes = Math.floor(seconds / 60)
        if (minutes < 60) return qsTr("%1m").arg(minutes)
        var hours = Math.floor(minutes / 60)
        if (hours < 24) return qsTr("%1h").arg(hours)
        var days = Math.floor(hours / 24)
        return qsTr("%1d").arg(days)
    }

    function scrollToTop() {
        listView.scrollToTop()
        scrollTracker.reset()
    }
}
