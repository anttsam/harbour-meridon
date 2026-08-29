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
        case "poll": return qsTr("a poll you voted in has ended")
        case "update": return qsTr("edited a post you interacted with")
        default: return reason
        }
    }

    function reasonIcon(reason) {
        switch (reason) {
        case "favourite": return "image://theme/icon-s-like"
        case "reblog": return "image://theme/icon-s-retweet"
        case "follow":
        case "follow_request": return "image://theme/icon-m-user"
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
            contentHeight: Theme.itemSizeMedium

            onClicked: {
                if (model.statusId && model.statusId.length > 0) {
                    pageStack.push(Qt.resolvedUrl("../PostDetailPage.qml"), {
                        postUri: model.statusId
                    })
                }
            }

            Row {
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                Image {
                    width: Theme.iconSizeSmall
                    height: Theme.iconSizeSmall
                    source: notificationsView.reasonIcon(model.reason)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - Theme.iconSizeSmall - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter

                    AppLabel {
                        width: parent.width
                        text: AppLib.EmojiManager.render(model.displayName || model.handle, model.emojisJson, (Theme.fontSizeSmall) * sizeMultiplier) + " " + notificationsView.reasonLabel(model.reason)
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                        color: model.isRead ? Theme.secondaryColor : Theme.primaryColor
                    }

                    AppLabel {
                        text: model.timeAgo
                        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                        color: Theme.secondaryColor
                    }
                }
            }
        }

        VerticalScrollDecorator {}

        // Declared here (not as a sibling) so it lands in this ListView's
        // own contentItem via Flickable's default property - see
        // ListManagePage.qml's matching comment for why this placement is
        // what actually lets ViewPlaceholder find its flickable ancestor.
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
                busy = false

                if (reset)
                    notificationsModel.clear()

                var notifs = response || []
                console.log("[Notifications] got", notifs.length)

                for (var i = 0; i < notifs.length; i++) {
                    var n = notifs[i]
                    notificationsModel.append({
                        reason: n.type,
                        displayName: (n.account && n.account.display_name) || "",
                        emojisJson: PostMapper.emojiMapJson(n.account && n.account.emojis),
                        handle: n.account ? n.account.acct : "",
                        // Mastodon's core API doesn't expose read status, so all true
                        isRead: true,
                        timeAgo: formatTimeAgo(n.created_at),
                        statusId: n.status ? n.status.id : ""
                    })
                }

                nextCursor = PostMapper.parseNextCursor(linkHeader)
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
