import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib" as AppLib
import "../lib/SessionManager.js" as SessionManager
import "../lib/PostMapper.js" as PostMapper

AppPage {
    id: followListPage
    //backgroundColor: "#181820"

    property string did: ""
    property string handle: ""
    property string mode: "followers" // "followers" | "following"
    property int totalCount: 0

    property bool busy: false
    property string errorText: ""
    property string nextCursor: ""

    // Guards checkLoadMore()
    property string lastLoadMoreCursor: ""

    ListModel {
        id: userModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: userModel

        header: PageHeader {
            title: "@" + followListPage.handle
            description: followListPage.mode === "followers"
                ? qsTr("%1 Followers").arg(PostMapper.formatCount(followListPage.totalCount))
                : qsTr("%1 Following").arg(PostMapper.formatCount(followListPage.totalCount))
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: followListPage.load(true)
            }
        }

        function checkLoadMore() {
            if (!busy && nextCursor.length > 0 && nextCursor !== lastLoadMoreCursor && atYEnd) {
                lastLoadMoreCursor = nextCursor
                followListPage.load(false)
            }
        }
        onAtYEndChanged: checkLoadMore()
        onMovementEnded: checkLoadMore()

        delegate: ListItem {
            id: userDelegate
            contentHeight: userColumn.height + 2 * Theme.paddingMedium

            onClicked: pageStack.push(Qt.resolvedUrl("UserProfilePage.qml"), {
                did: model.userDid
            })

            Column {
                id: userColumn
                x: Theme.horizontalPageMargin
                y: Theme.paddingMedium
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                Row {
                    id: userRow
                    width: parent.width
                    spacing: Theme.paddingMedium

                    RoundedAvatar {
                        size: Theme.iconSizeMedium
                        source: model.avatarUrl
                    }

                    Column {
                        width: parent.width - Theme.iconSizeMedium - followButton.width - parent.spacing * 2
                        spacing: Theme.paddingSmall

                        AppLabel {
                            width: parent.width
                            text: AppLib.EmojiManager.render(model.displayName || model.handle, model.emojisJson, (Theme.fontSizeSmall) * sizeMultiplier)
                            textFormat: Text.StyledText
                            bold: true
                            font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                            truncationMode: TruncationMode.Fade
                        }

                        AppLabel {
                            width: parent.width
                            text: "@" + model.handle
                            color: Theme.secondaryColor
                            font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                            truncationMode: TruncationMode.Fade
                        }
                    }

                    SecondaryButton {
                        id: followButton
                        preferredWidth: Theme.buttonWidthExtraSmall
                        visible: model.userDid !== SessionManager.getCurrentUserId() // Hide for yourself
                        text: model.viewerFollowing ? qsTr("Following") : qsTr("+ Follow")
                        color: model.viewerFollowing
                            ? Theme.secondaryColor : palette.secondaryHighlightColor
                        onClicked: followListPage.toggleFollow(index)
                    }
                }

                AppLabel {
                    x: Theme.iconSizeMedium + Theme.paddingMedium
                    width: parent.width - x
                    text: model.description
                    textFormat: Text.StyledText // Mastodon's account.note is HTML
                    visible: model.description.length > 0
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                    color: Theme.primaryColor
                    linkColor: Theme.secondaryColor
                }
            }
        }

        VerticalScrollDecorator {}

        // Declared here (not as a sibling) so it lands in this ListView's
        // own contentItem via Flickable's default property - see
        // ListManagePage.qml's matching comment for why this placement is
        // what actually lets ViewPlaceholder find its flickable ancestor.
        ViewPlaceholder {
            enabled: !followListPage.busy && userModel.count === 0 && errorText.length === 0
            text: followListPage.mode === "followers"
                ? qsTr("No followers yet") : qsTr("Not following anyone yet")
        }

        ViewPlaceholder {
            enabled: errorText.length > 0 && userModel.count === 0
            text: qsTr("Couldn't load list")
            hintText: errorText
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: followListPage.busy && userModel.count === 0
        visible: running
        size: BusyIndicatorSize.Large
    }

    Component.onCompleted: load(true)

    function appendAccounts(accounts, followingById) {
        for (var i = 0; i < accounts.length; i++) {
            var u = accounts[i]
            userModel.append({
                userDid: u.id,
                handle: u.acct,
                displayName: u.display_name || "",
                emojisJson: PostMapper.emojiMapJson(u.emojis),
                avatarUrl: u.avatar || "",
                description: PostMapper.stripTrailingParagraph(u.note),
                viewerFollowing: followingById ? (followingById[u.id] === true) : false
            })
        }
    }

    function load(reset) {
        if (busy || did.length === 0)
            return

        busy = true
        if (reset) {
            errorText = ""
            nextCursor = ""
            lastLoadMoreCursor = ""
        }

        var endpoint = mode === "followers" ? "followers" : "following"
        var path = "/api/v1/accounts/" + encodeURIComponent(did) + "/" + endpoint + "?limit=30"
        if (!reset && nextCursor.length > 0)
            path += "&max_id=" + encodeURIComponent(nextCursor)

        SessionManager.authenticatedRequest("GET", path, null,
            function(response, linkHeader) {
                var accounts = response || []
                nextCursor = PostMapper.parseNextCursor(linkHeader)

                if (reset)
                    userModel.clear()

                if (accounts.length === 0) {
                    busy = false
                    return
                }

                // Mastodon's account list endpoints return bare accounts - a second, batched call is needed to
                // learn which of them the current user follows.
                var relQuery = accounts.map(function(a) {
                    return "id[]=" + encodeURIComponent(a.id)
                }).join("&")

                SessionManager.authenticatedRequest("GET",
                    "/api/v1/accounts/relationships?" + relQuery, null,
                    function(relResponse) {
                        busy = false
                        var followingById = {}
                        var rels = relResponse || []
                        for (var r = 0; r < rels.length; r++)
                            followingById[rels[r].id] = !!rels[r].following
                        appendAccounts(accounts, followingById)
                    },
                    function(status, message) {
                        busy = false
                        console.warn("[FollowList] relationships lookup failed:", status, message)
                        // Show the list anyway, just without follow-state
                        appendAccounts(accounts, null)
                    }
                )
            },
            function(status, message) {
                busy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
                } else {
                    errorText = qsTr("Couldn't load list (%1)").arg(message || status)
                }
            }
        )
    }

    // optimistic-toggle pattern
    function toggleFollow(index) {
        var item = userModel.get(index)
        if (!item || !item.userDid)
            return

        var wasFollowing = item.viewerFollowing
        var action = wasFollowing ? "unfollow" : "follow"
        userModel.setProperty(index, "viewerFollowing", !wasFollowing)

        SessionManager.authenticatedRequest("POST",
            "/api/v1/accounts/" + encodeURIComponent(item.userDid) + "/" + action, {},
            function(response) {
                userModel.setProperty(index, "viewerFollowing", !!response.following)
            },
            function(status, message) {
                console.warn("[FollowList]", action, "failed:", status, message)
                userModel.setProperty(index, "viewerFollowing", wasFollowing)
            }
        )
    }
}
