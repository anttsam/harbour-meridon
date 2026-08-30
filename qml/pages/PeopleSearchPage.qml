import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager
import "../lib/PostMapper.js" as PostMapper

// GET /api/v2/search?type=accounts

AppPage {
    id: page

    property string query: ""

    property bool busy: false
    property string errorText: ""
    property bool hasMore: true
    property int lastLoadMoreCount: -1

    ListModel {
        id: accountsModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: accountsModel

        header: PageHeader {
            title: qsTr("People matching “%1”").arg(page.query)
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: page.load(true)
            }
        }

        function checkLoadMore() {
            if (!busy && page.hasMore && accountsModel.count !== lastLoadMoreCount && atYEnd) {
                lastLoadMoreCount = accountsModel.count
                page.load(false)
            }
        }
        onAtYEndChanged: checkLoadMore()
        onMovementEnded: checkLoadMore()

        delegate: Item {
            id: accountDelegate
            width: listView.width
            height: card.height + Theme.paddingLarge

            Rectangle {
                id: card
                x: Theme.horizontalPageMargin / 2
                width: parent.width - Theme.horizontalPageMargin
                height: cardHeader.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.primaryColor, 0.06)
                border.color: Theme.rgba(Theme.primaryColor, 0.15)
                border.width: 1
                clip: true

                MouseArea {
                    anchors.fill: parent
                    onClicked: pageStack.push(Qt.resolvedUrl("UserProfilePage.qml"), {
                        did: model.userDid
                    })
                }

                ProfileHeader {
                    id: cardHeader
                    y: Theme.paddingMedium
                    did: model.userDid
                    currentUserDid: SessionManager.getCurrentUserId()
                    displayName: model.displayName
                    emojisJson: model.emojisJson
                    handle: model.handle
                    avatarUrl: model.avatarUrl
                    bannerUrl: model.bannerUrl
                    bio: model.bio
                    followersCount: model.followersCount
                    followsCount: model.followsCount
                    postsCount: model.postsCount
                    isBot: model.isBot
                    isLocked: model.isLocked
                    createdAt: model.createdAt
                    fieldsList: JSON.parse(model.fieldsListJson)
                    viewerFollowing: model.viewerFollowing
                    onFollowClicked: page.toggleFollow(index)
                }
            }
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: !page.busy && accountsModel.count === 0 && errorText.length === 0
            text: qsTr("No matches")
            hintText: qsTr("Try a different search term")
        }

        ViewPlaceholder {
            enabled: errorText.length > 0 && accountsModel.count === 0
            text: qsTr("Search failed")
            hintText: errorText
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: page.busy && accountsModel.count === 0
        visible: running
        size: BusyIndicatorSize.Large
    }

    Component.onCompleted: load(true)

    function appendAccounts(accounts, followingById) {
        for (var i = 0; i < accounts.length; i++) {
            var a = accounts[i]
            accountsModel.append({
                userDid: a.id,
                handle: a.acct || "",
                displayName: a.display_name || "",
                emojisJson: PostMapper.emojiMapJson(a.emojis),
                avatarUrl: a.avatar || "",
                bannerUrl: a.header || "",
                bio: PostMapper.stripTrailingParagraph(a.note),
                followersCount: a.followers_count || 0,
                followsCount: a.following_count || 0,
                postsCount: a.statuses_count || 0,
                isBot: !!a.bot,
                isLocked: !!a.locked,
                createdAt: a.created_at || "",
                fieldsListJson: JSON.stringify(a.fields || []),
                viewerFollowing: followingById ? (followingById[a.id] === true) : false
            })
        }
    }

    function load(reset) {
        var q = query.trim()
        if (busy || q.length === 0)
            return

        busy = true
        if (reset) {
            errorText = ""
            hasMore = true
            lastLoadMoreCount = -1
            accountsModel.clear()
        }

        var path = "/api/v2/search?q=" + encodeURIComponent(q)
            + "&type=accounts&resolve=true&limit=20&offset=" + accountsModel.count

        SessionManager.authenticatedRequest("GET", path, null,
            function(response) {
                var accounts = (response && response.accounts) || []
                hasMore = accounts.length > 0

                if (accounts.length === 0) {
                    busy = false
                    return
                }

                // Search results are bare accounts - a second, batched call is
                // needed to learn which of them the current user follows,
                // same as FollowListPage.qml/SuggestedAccountsPage.qml.
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
                        console.warn("[PeopleSearch] relationships lookup failed:", status, message)
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
                    errorText = qsTr("Couldn't search (%1)").arg(message || status)
                }
            }
        )
    }

    // optimistic-toggle pattern, same as FollowListPage.qml/SuggestedAccountsPage.qml
    function toggleFollow(index) {
        var item = accountsModel.get(index)
        if (!item || !item.userDid)
            return

        var wasFollowing = item.viewerFollowing
        var action = wasFollowing ? "unfollow" : "follow"
        accountsModel.setProperty(index, "viewerFollowing", !wasFollowing)

        SessionManager.authenticatedRequest("POST",
            "/api/v1/accounts/" + encodeURIComponent(item.userDid) + "/" + action, {},
            function(response) {
                accountsModel.setProperty(index, "viewerFollowing", !!response.following)
            },
            function(status, message) {
                console.warn("[PeopleSearch]", action, "failed:", status, message)
                accountsModel.setProperty(index, "viewerFollowing", wasFollowing)
            }
        )
    }
}
