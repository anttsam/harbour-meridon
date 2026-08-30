import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager
import "../lib/PostMapper.js" as PostMapper
import "../lib/FeedsManager.js" as FeedsManager

AppPage {
    id: profilePage

    property string did: ""
    // Set instead of did when a handle (e.g. "Go to @user@server" from
    // search) couldn't be resolved to an account - shown as the error text.
    property string unresolvedHandle: ""

    property bool profileBusy: false
    property string profileError: ""

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
    property var familiarFollowers: []

    property bool viewerFollowing: false
    property bool viewerBlocking: false
    property bool viewerMuted: false

    property bool actionBusy: false
    property string actionError: ""

    property bool feedBusy: false
    property string feedError: ""
    property string nextCursor: ""

    // Guards checkLoadMore() against firing more than once
    property string lastLoadMoreCursor: ""

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
                id: userHeader
                did: profilePage.did
                displayName: profilePage.displayName
                emojisJson: profilePage.emojisJson
                handle: profilePage.handle
                avatarUrl: profilePage.avatarUrl
                bannerUrl: profilePage.bannerUrl
                bio: profilePage.bio
                followersCount: profilePage.followersCount
                followsCount: profilePage.followsCount
                postsCount: profilePage.postsCount
                isBot: profilePage.isBot
                isLocked: profilePage.isLocked
                createdAt: profilePage.createdAt
                fieldsList: profilePage.fieldsList
                familiarFollowers: profilePage.familiarFollowers
                currentUserDid: SessionManager.getCurrentUserId()
                viewerFollowing: profilePage.viewerFollowing
                onFollowClicked: profilePage.toggleFollow()
            }

            //Item { width: 1; height: Theme.paddingMedium } //was Large before

            AppLabel {
                useCustomFont: true
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: actionError.length > 0
                text: actionError
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                bottomPadding: Theme.paddingMedium

                Timer {
                    interval: 3000
                    running: actionError.length > 0
                    onTriggered: actionError = ""
                }
            }

            SectionHeader { text: qsTr("Posts") }
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Report")
                // Placeholder - needs a reason-selection UI
                // (POST /api/v1/reports takes a category/comment) that
                // isn't built yet.
                onClicked: actionError = qsTr("Report isn't available yet")
            }

            MenuItem {
                text: profilePage.viewerBlocking ? qsTr("Unblock") : qsTr("Block")
                onClicked: profilePage.toggleBlock()
            }

            MenuItem {
                text: profilePage.viewerMuted ? qsTr("Unmute") : qsTr("Mute")
                onClicked: profilePage.toggleMute()
            }

            MenuItem {
                text: qsTr("Share")
                onClicked: profilePage.shareProfile()
            }

            MenuItem {
                // Mastodon's API rejects POST /api/v1/lists/:id/accounts
                // with 422 "Account must be a followed account" for anyone
                // you don't already follow (Mastodon's own web client has
                // the same underlying gap - mastodon/mastodon#34468 - but
                // doesn't explain it; the official iOS app shows "You must
                // follow @handle first before adding them to a list",
                // which this mirrors). MenuItem is a plain Label with no
                // subtitle of its own, so the explanation has to be the
                // item's own text while it's disabled, rather than hiding
                // it outright.
                enabled: profilePage.viewerFollowing
                text: profilePage.viewerFollowing
                    ? qsTr("Add to List")
                    : qsTr("Follow %1 to add them to a list").arg(profilePage.handle)
                onClicked: profilePage.openListPicker()
            }

            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    profilePage.loadProfile()
                    profilePage.loadFeed(true)
                }
            }
        }

        function checkLoadMore() {
            if (!feedBusy && nextCursor.length > 0 && nextCursor !== lastLoadMoreCursor && atYEnd
                && (profilePage.currentSection === "posts" || profilePage.currentSection === "likes")) {
                lastLoadMoreCursor = nextCursor
                profilePage.loadFeed(false)
            }
        }
        onAtYEndChanged: checkLoadMore()
        onMovementEnded: checkLoadMore()

        delegate: PostDelegate {}

        // With 0 posts loaded, this sits directly below the header's own
        // "Posts" SectionHeader - was previously a page-centered
        // BusyIndicator, which started overlapping ProfileHeader's own
        // content once that got noticeably faster to render, since
        // centering on the whole page has no idea where the profile info
        // actually ends and the posts section begins.
        footer: Item {
            width: parent ? parent.width : 0
            height: (profilePage.profileBusy || (profilePage.feedBusy && postsModel.count === 0))
                ? Theme.itemSizeLarge : 0

            BusyIndicator {
                anchors.centerIn: parent
                running: profilePage.profileBusy || (profilePage.feedBusy && postsModel.count === 0)
                visible: running
                size: BusyIndicatorSize.Large
            }
        }

        VerticalScrollDecorator {}

        // Declared here (not as a sibling) so it lands in this ListView's
        // own contentItem via Flickable's default property - see
        // ListManagePage.qml's matching comment for why this placement is
        // what actually lets ViewPlaceholder find its flickable ancestor.
        ViewPlaceholder {
            enabled: profileError.length > 0
            text: qsTr("Couldn't load profile")
            hintText: profileError
        }
    }

    Component.onCompleted: {
        loadProfile()
        loadFeed(true)
    }

    // This is not supposed to be here, remove
    function openListPicker() {
        var picker = pageStack.push(Qt.resolvedUrl("ListPickerPage.qml"), {
            subjectDid: profilePage.did,
            subjectName: profilePage.displayName || profilePage.handle
        })
        picker.listPicked.connect(function(list) {
            profilePage.addToList(list)
        })
    }

    function loadProfile() {
        if (did.length === 0) {
            profileError = unresolvedHandle.length > 0
                ? qsTr("Couldn't find @%1").arg(unresolvedHandle)
                : qsTr("No profile specified")
            return
        }

        profileBusy = true
        profileError = ""

        // Three calls, joined below: unlike AT Proto's getProfile (which
        // embedded a "viewer" object with following/blocking/muted state
        // directly in the response), Mastodon's relationship state - and
        // familiar-followers - are separate endpoints.
        var account = null
        var relationship = null
        var familiar = null
        var pending = 3
        var sessionExpired = false

        function handleFailure(status, message) {
            if (status === 401 && !sessionExpired) {
                sessionExpired = true
                SessionManager.clearSession()
                pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
                return
            }
            if (status !== 401)
                console.warn("[UserProfile] request failed:", status, message)
            pending -= 1
            checkDone()
        }

        function checkDone() {
            if (pending > 0)
                return

            profileBusy = false

            if (sessionExpired)
                return

            if (!account) {
                profileError = qsTr("Couldn't load profile")
                return
            }

            displayName = account.display_name || ""
            emojisJson = PostMapper.emojiMapJson(account.emojis)
            handle = account.acct || ""
            avatarUrl = account.avatar || ""
            bannerUrl = account.header || ""
            bio = PostMapper.stripTrailingParagraph(account.note)
            followersCount = account.followers_count || 0
            followsCount = account.following_count || 0
            postsCount = account.statuses_count || 0
            isBot = !!account.bot
            isLocked = !!account.locked
            createdAt = account.created_at || ""
            fieldsList = account.fields || []

            viewerFollowing = !!(relationship && relationship.following)
            viewerBlocking = !!(relationship && relationship.blocking)
            viewerMuted = !!(relationship && relationship.muting)

            familiarFollowers = (familiar && familiar.accounts) || []
        }

        SessionManager.authenticatedRequest("GET",
            "/api/v1/accounts/" + encodeURIComponent(did), null,
            function(response) {
                account = response
                pending -= 1
                checkDone()
            },
            handleFailure
        )

        SessionManager.authenticatedRequest("GET",
            "/api/v1/accounts/relationships?id[]=" + encodeURIComponent(did), null,
            function(response) {
                relationship = (response && response[0]) || null
                pending -= 1
                checkDone()
            },
            handleFailure
        )

        // Non-essential to the page working - checkDone() already treats
        // a missing/failed familiar list as "no familiar followers" rather
        // than an error, same as the account/relationship calls above
        // still complete the page even if this one alone fails.
        SessionManager.authenticatedRequest("GET",
            "/api/v1/accounts/familiar_followers?id[]=" + encodeURIComponent(did), null,
            function(response) {
                familiar = (response && response[0]) || null
                pending -= 1
                checkDone()
            },
            handleFailure
        )
    }

    function loadFeed(reset) {
        if (feedBusy || did.length === 0)
            return

        feedBusy = true
        if (reset) {
            feedError = ""
            nextCursor = ""
            lastLoadMoreCursor = ""
        }

        var path = "/api/v1/accounts/" + encodeURIComponent(did) + "/statuses?limit=30"
        if (!reset && nextCursor.length > 0)
            path += "&max_id=" + encodeURIComponent(nextCursor)

        SessionManager.authenticatedRequest("GET", path, null,
            function(response, linkHeader) {
                var statuses = response || []
                var parsedCursor = PostMapper.parseNextCursor(linkHeader)

                FeedsManager.mapStatusesAsync(statuses, function(rows) {
                    feedBusy = false

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
                    pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
                } else {
                    feedError = qsTr("Couldn't load posts (%1)").arg(message || status)
                }
            }
        )
    }

    // Follow/block/mute are toggles on Mastodon
    function toggleFollow() {
        if (actionBusy)
            return
        actionBusy = true

        var wasFollowing = viewerFollowing
        var action = wasFollowing ? "unfollow" : "follow"

        SessionManager.authenticatedRequest("POST",
            "/api/v1/accounts/" + encodeURIComponent(did) + "/" + action, {},
            function(response) {
                actionBusy = false
                viewerFollowing = !!response.following
                followersCount = Math.max(0, followersCount + (viewerFollowing ? 1 : -1))
            },
            function(status, message) {
                actionBusy = false
                actionError = wasFollowing
                    ? qsTr("Couldn't unfollow (%1)").arg(message || status)
                    : qsTr("Couldn't follow (%1)").arg(message || status)
            }
        )
    }

    function toggleMute() {
        if (actionBusy)
            return
        actionBusy = true

        var action = viewerMuted ? "unmute" : "mute"

        SessionManager.authenticatedRequest("POST",
            "/api/v1/accounts/" + encodeURIComponent(did) + "/" + action, {},
            function(response) {
                actionBusy = false
                viewerMuted = !!response.muting
            },
            function(status, message) {
                actionBusy = false
                actionError = qsTr("Couldn't update mute (%1)").arg(message || status)
            }
        )
    }

    function toggleBlock() {
        if (actionBusy)
            return
        actionBusy = true

        var action = viewerBlocking ? "unblock" : "block"

        SessionManager.authenticatedRequest("POST",
            "/api/v1/accounts/" + encodeURIComponent(did) + "/" + action, {},
            function(response) {
                actionBusy = false
                viewerBlocking = !!response.blocking
            },
            function(status, message) {
                actionBusy = false
                actionError = viewerBlocking
                    ? qsTr("Couldn't unblock (%1)").arg(message || status)
                    : qsTr("Couldn't block (%1)").arg(message || status)
            }
        )
    }

    function shareProfile() {
        var session = SessionManager.getSession()
        var instanceUrl = session ? session.instanceUrl : ""
        var url = instanceUrl + "/@" + (handle.length > 0 ? handle : did)
        Clipboard.text = url
        actionError = qsTr("Profile link copied")
    }

    function addToList(list) {
        SessionManager.authenticatedRequest("POST",
            "/api/v1/lists/" + encodeURIComponent(list.id) + "/accounts",
            { account_ids: [profilePage.did] },
            function(response) {
                actionError = qsTr("Added to %1").arg(list.name)
            },
            function(status, message) {
                // 422 here is specifically Mastodon's "Account must be a
                // followed account" - the Add to List menu item is hidden
                // for accounts we don't follow (see above), but relationship
                // state can still be stale (e.g. unfollowed elsewhere since
                // this page loaded), so this stays as a safety net.
                actionError = status === 422
                    ? qsTr("You need to follow %1 before adding them to a list").arg(profilePage.displayName || profilePage.handle)
                    : qsTr("Couldn't add to list (%1)").arg(message || status)
            }
        )
    }
}
