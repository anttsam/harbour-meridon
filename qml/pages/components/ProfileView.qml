import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib/SessionManager.js" as SessionManager
import "../../lib/PostMapper.js" as PostMapper
import "../../lib/FeedsManager.js" as FeedsManager

Item {
    id: profileView

    property bool busy: false
    property string errorText: ""

    property string did: ""
    property string displayName: ""
    property string emojisJson: "{}"
    property string handle: ""
    property string avatarUrl: ""
    property string bannerUrl: ""
    property string bio: ""
    property int followersCount: 0
    property int followsCount: 0
    property int postsCount: 0
    property bool isBot: false
    property bool isLocked: false
    property string createdAt: ""
    property var fieldsList: []

    property string currentSection: "posts"

    // MainPage owns all picker attach/detach
    signal requestPicker()

    property bool feedBusy: false
    property string feedError: ""
    property string nextCursor: ""

    // Guards the onContentYChanged load-more check below against firing
    // more than once for the same page of results
    property string lastLoadMoreCursor: ""

    ScrollDirectionTracker {
        id: scrollTracker
        target: listView
    }
    property alias tabBarHidden: scrollTracker.hidden

    ListModel {
        id: postsModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: postsModel

        header: Column {
            width: parent.width

            ProfileHeader {
                did: profileView.did
                displayName: profileView.displayName
                emojisJson: profileView.emojisJson
                handle: profileView.handle
                avatarUrl: profileView.avatarUrl
                bannerUrl: profileView.bannerUrl
                bio: profileView.bio
                followersCount: profileView.followersCount
                followsCount: profileView.followsCount
                postsCount: profileView.postsCount
                isBot: profileView.isBot
                isLocked: profileView.isLocked
                createdAt: profileView.createdAt
                fieldsList: profileView.fieldsList
                currentUserDid: SessionManager.getCurrentUserId()
            }

            Item { width: 1; height: Theme.paddingMedium }

            PageHeader {
                title: profileView.sectionLabel(profileView.currentSection)

                MouseArea {
                    anchors.fill: parent
                    onClicked: profileView.requestPicker()
                }
            }
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Log out")
                onClicked: {
                    Remorse.popupAction(profileView, qsTr("Logging out"), function() {
                        SessionManager.clearSession()
                        pageStack.animatorReplace(Qt.resolvedUrl("../FirstPage.qml"))
                    })
                }
            }
            MenuItem {
                text: qsTr("Manage Lists")
                onClicked: pageStack.push(Qt.resolvedUrl("../ListManagePage.qml"))
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("../SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    profileView.loadProfile()
                    profileView.loadFeed(true)
                }
            }
        }

        onContentYChanged: {
            if (!feedBusy && nextCursor.length > 0 && nextCursor !== lastLoadMoreCursor
                && (profileView.currentSection === "posts" || profileView.currentSection === "likes"
                    || profileView.currentSection === "bookmarks")
                && contentY + height > contentHeight - Theme.itemSizeLarge * 3) {
                lastLoadMoreCursor = nextCursor
                profileView.loadFeed(false)
            }
        }

        delegate: PostDelegate {}

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: errorText.length > 0
            text: qsTr("Couldn't load profile")
            hintText: errorText
        }

        ViewPlaceholder {
            // no content to show
            enabled: !profileView.busy && errorText.length === 0
                && profileView.currentSection !== "posts" && profileView.currentSection !== "likes"
                && profileView.currentSection !== "bookmarks"
            text: profileView.sectionLabel(profileView.currentSection)
            hintText: qsTr("Not available yet")
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: profileView.busy || (feedBusy && postsModel.count === 0)
        visible: running
        size: BusyIndicatorSize.Large
    }

    // Staggered fetch
    Timer {
        id: startupLoadTimer
        interval: 800
        running: true
        repeat: false
        onTriggered: {
            profileView.loadProfile()
            profileView.loadFeed(true)
        }
    }

    function sectionLabel(key) {
        switch (key) {
        case "posts": return qsTr("Posts")
        case "replies": return qsTr("Replies")
        case "media": return qsTr("Media")
        case "videos": return qsTr("Videos")
        case "likes": return qsTr("Likes")
        case "bookmarks": return qsTr("Bookmarks")
        case "lists": return qsTr("Lists")
        default: return key
        }
    }

    // Called by MainPage after it switches the picker attach, nicer would be a carousel...
    function switchSection(section) {
        if (section === profileView.currentSection)
            return
        profileView.currentSection = section
        postsModel.clear()
        listView.scrollToTop()
        if (section === "posts" || section === "likes" || section === "bookmarks")
            loadFeed(true)
    }

    function loadProfile() {
        var session = SessionManager.getSession()
        if (!session) {
            errorText = qsTr("Not logged in")
            return
        }

        did = session.accountId
        busy = true
        errorText = ""

        console.log("[Profile] fetching own profile")

        SessionManager.authenticatedRequest("GET", "/api/v1/accounts/verify_credentials", null,
            function(response) {
                busy = false
                displayName = response.display_name || ""
                emojisJson = PostMapper.emojiMapJson(response.emojis)
                handle = response.acct || ""
                avatarUrl = response.avatar || ""
                bannerUrl = response.header || ""
                bio = PostMapper.stripTrailingParagraph(response.note)
                followersCount = response.followers_count || 0
                followsCount = response.following_count || 0
                postsCount = response.statuses_count || 0
                isBot = !!response.bot
                isLocked = !!response.locked
                createdAt = response.created_at || ""
                fieldsList = response.fields || []
            },
            function(status, message) {
                busy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("../FirstPage.qml"))
                } else {
                    errorText = qsTr("Couldn't load profile (%1)").arg(message || status)
                }
            }
        )
    }

    function loadFeed(reset) {
        var session = SessionManager.getSession()
        if ((feedBusy && !reset) || !session)
            return
        if (currentSection !== "posts" && currentSection !== "likes" && currentSection !== "bookmarks")
            return

        feedBusy = true
        if (reset) {
            feedError = ""
            nextCursor = ""
            lastLoadMoreCursor = ""
        }

        var requestedSection = currentSection

        // Note: Mastodon has no per-account "likes"/"bookmarks" endpoint
        var path
        if (currentSection === "likes")
            path = "/api/v1/favourites?limit=30"
        else if (currentSection === "bookmarks")
            path = "/api/v1/bookmarks?limit=30"
        else
            path = "/api/v1/accounts/" + encodeURIComponent(session.accountId) + "/statuses?limit=30"
        if (!reset && nextCursor.length > 0)
            path += "&max_id=" + encodeURIComponent(nextCursor)

        SessionManager.authenticatedRequest("GET", path, null,
            function(response, linkHeader) {
                var statuses = response || []
                var parsedCursor = PostMapper.parseNextCursor(linkHeader)

                FeedsManager.mapStatusesAsync(statuses, function(rows) {
                    feedBusy = false

                    if (profileView.currentSection !== requestedSection) {
                        console.log("[Profile] discarding stale response for", requestedSection)
                        return
                    }

                    if (reset)
                        postsModel.clear()

                    for (var i = 0; i < rows.length; i++)
                        postsModel.append(rows[i])

                    nextCursor = parsedCursor
                })
            },
            function(status, message) {
                feedBusy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("../FirstPage.qml"))
                } else {
                    feedError = qsTr("Couldn't load (%1)").arg(message || status)
                }
            }
        )
    }

    function scrollToTop() {
        listView.scrollToTop()
        scrollTracker.reset()
    }
}
