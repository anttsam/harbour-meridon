import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager
import "../lib/PostMapper.js" as PostMapper

// Mastodon's GET /api/v2/suggestions

AppPage {
    id: page

    property bool busy: false
    property string errorText: ""

    ListModel {
        id: accountsModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: accountsModel

        header: PageHeader {
            title: qsTr("For You")
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: page.load()
            }
        }

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
            text: qsTr("No suggestions yet")
        }

        ViewPlaceholder {
            enabled: errorText.length > 0 && accountsModel.count === 0
            text: qsTr("Couldn't load")
            hintText: errorText
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: page.busy && accountsModel.count === 0
        visible: running
        size: BusyIndicatorSize.Large
    }

    Component.onCompleted: load()

    function load() {
        if (busy)
            return

        busy = true
        errorText = ""

        SessionManager.authenticatedRequest("GET", "/api/v2/suggestions?limit=40", null,
            function(response) {
                busy = false
                accountsModel.clear()
                var suggestions = response || []
                for (var i = 0; i < suggestions.length; i++) {
                    var a = suggestions[i].account || {}
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
                        viewerFollowing: false
                    })
                }
            },
            function(status, message) {
                busy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
                } else {
                    errorText = qsTr("Couldn't load suggestions (%1)").arg(message || status)
                }
            }
        )
    }

    // optimistic-toggle pattern, same as FollowListPage.qml's own
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
                console.warn("[SuggestedAccounts]", action, "failed:", status, message)
                accountsModel.setProperty(index, "viewerFollowing", wasFollowing)
            }
        )
    }
}
