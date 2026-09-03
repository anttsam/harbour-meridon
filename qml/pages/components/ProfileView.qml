import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib/SessionManager.js" as SessionManager
import "../../lib/PostMapper.js" as PostMapper
import "../../lib/FeedsManager.js" as FeedsManager
import "../../lib/VideoExpansionTracker.js" as VideoExpansionTracker

// using now the same shape as FeedCarouselView.qml/FeedPane.qml

Item {
    id: profileView

    property bool isPortrait: true

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

    // The carousel below is only built once real profile data has arrived
    readonly property bool profileReady: handle.length > 0

    // Per-section content cache, owned here so it survives SlideshowView recycling
    property var _sectionContent: ({})

    function getSectionContent(key, anchor) {
        if (!_sectionContent[key]) {
            _sectionContent[key] = {
                model: Qt.createQmlObject("import QtQuick 2.0; ListModel {}",
                    anchor, "ProfileSectionModel"),
                busy: false,
                nextCursor: "",
                lastLoadMoreCursor: "",
                loadedOnce: false,
                errorText: ""
            }
        }
        return _sectionContent[key]
    }

    // Lives here, not on any one carousel delegate
    function loadSection(sectionKey, reset, onDone) {
        var session = SessionManager.getSession()
        var content = getSectionContent(sectionKey, profileView)
        if (content.busy && !reset) {
            if (onDone) onDone(true, "", 0)
            return
        }
        if (!session) {
            if (onDone) onDone(false, "Not logged in", 0)
            return
        }

        content.busy = true
        if (reset) {
            content.errorText = ""
            content.nextCursor = ""
            content.lastLoadMoreCursor = ""
        }

        // Note: these are always the logged-in user's own.
        var path
        if (sectionKey === "likes")
            path = "/api/v1/favourites?limit=20"
        else if (sectionKey === "bookmarks")
            path = "/api/v1/bookmarks?limit=20"
        else
            path = "/api/v1/accounts/" + encodeURIComponent(session.accountId) + "/statuses?limit=20"
        if (!reset && content.nextCursor.length > 0)
            path += "&max_id=" + encodeURIComponent(content.nextCursor)

        SessionManager.authenticatedRequest("GET", path, null,
            function(response, linkHeader) {
                var statuses = response || []
                var parsedCursor = PostMapper.parseNextCursor(linkHeader)

                FeedsManager.mapStatusesAsync(statuses, function(rows) {
                    content.busy = false
                    content.loadedOnce = true

                    if (reset)
                        content.model.clear()

                    for (var i = 0; i < rows.length; i++)
                        content.model.append(rows[i])

                    content.nextCursor = parsedCursor

                    if (onDone) onDone(true, "", 0)
                })
            },
            function(status, message) {
                content.busy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("../FirstPage.qml"))
                } else {
                    content.errorText = qsTr("Couldn't load (%1)").arg(message || status)
                }
                if (onDone) onDone(false, message, status)
            }
        )
    }

    property bool tabBarHidden: false
    property bool stripHidden: false

    Connections {
        target: carouselLoader.item ? carouselLoader.item.slideshow.currentItem : null
        ignoreUnknownSignals: true
        onTabBarHiddenChanged: {
            profileView.tabBarHidden = carouselLoader.item.slideshow.currentItem.tabBarHidden
            profileView.stripHidden = carouselLoader.item.slideshow.currentItem.tabBarHidden
        }
    }

    // Staggered fetch
    Timer {
        id: startupLoadTimer
        interval: 800
        running: true
        repeat: false
        onTriggered: {
            profileView.loadProfile()
            profileView.loadSection("posts", true)
        }
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

    function scrollToTop() {
        if (carouselLoader.item && carouselLoader.item.slideshow.currentItem)
            carouselLoader.item.slideshow.currentItem.scrollToTop()
    }

    ListModel {
        id: sectionsModel
        Component.onCompleted: {
            append({ key: "posts", displayName: qsTr("Profile") })
            append({ key: "likes", displayName: qsTr("Favourites") })
            append({ key: "bookmarks", displayName: qsTr("Bookmarks") })
        }
    }

    Loader {
        id: carouselLoader
        anchors.fill: parent
        active: profileView.profileReady
        sourceComponent: carouselComponent
    }

    Component {
        id: carouselComponent

        Item {
            id: carouselRoot
            anchors.fill: parent

            property alias slideshow: slideshow

            property bool anyVideoExpanded: false
            readonly property bool topStripShouldShow: !anyVideoExpanded && !profileView.stripHidden

            onTopStripShouldShowChanged: {
                if (topStripShouldShow)
                    tabStripPanel.show()
                else
                    tabStripPanel.hide()
            }

            Component.onCompleted: {
                VideoExpansionTracker.subscribe(function(expanded) {
                    carouselRoot.anyVideoExpanded = expanded
                })
                // Explicit initial call
                if (topStripShouldShow)
                    tabStripPanel.show()
                else
                    tabStripPanel.hide()
            }

            Component {
                id: profileHeaderComponent

                Column{
                    spacing: Theme.paddingMedium
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
                    SectionHeader {
                        text: "Activity"
                    }
                }
            }

            SlideshowView {
                id: slideshow
                anchors {
                    top: parent.top
                    topMargin: tabStripPanel.visibleSize
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                clip: true
                model: sectionsModel

                delegate: Item {
                    id: sectionPane
                    width: slideshow.width
                    height: slideshow.height

                    readonly property string sectionKey: model.key
                    readonly property var content: profileView.getSectionContent(sectionKey, profileView)
                    readonly property bool isCurrent: !PathView.view || PathView.isCurrentItem

                    property bool busy: false
                    property string errorText: ""

                    ScrollDirectionTracker {
                        id: scrollTracker
                        target: innerList
                    }
                    property alias tabBarHidden: scrollTracker.hidden

                    function checkLoad() {
                        if (isCurrent && !content.loadedOnce && !content.busy)
                            load(true)
                    }
                    onIsCurrentChanged: checkLoad()
                    Component.onCompleted: checkLoad()

                    function load(reset) {
                        if (busy && !reset)
                            return

                        busy = true
                        if (reset)
                            errorText = ""

                        profileView.loadSection(sectionKey, reset, function(success, message, status) {
                            busy = false
                            if (!success)
                                errorText = qsTr("Couldn't load (%1)").arg(message || status)
                        })
                    }

                    function scrollToTop() {
                        innerList.scrollToTop()
                        scrollTracker.reset()
                    }

                    SilicaListView {
                        id: innerList
                        anchors.fill: parent
                        model: sectionPane.content.model
                        // Only the Posts pane gets ProfileHeader
                        header: Loader {
                            width: innerList.width
                            sourceComponent: sectionPane.sectionKey === "posts" ? profileHeaderComponent : null
                        }

                        PullDownMenu {
                            busy: sectionPane.busy
                            opacity: (sectionPane.sectionKey === "posts") ? 1: active ? 1 : 0
                            MenuItem {
                                text: qsTr("Log out")
                                visible: (sectionPane.sectionKey === "posts")
                                onClicked: {
                                    Remorse.popupAction(sectionPane, qsTr("Logging out"), function() {
                                        SessionManager.clearSession()
                                        pageStack.animatorReplace(Qt.resolvedUrl("../FirstPage.qml"))
                                    })
                                }
                            }
                            MenuItem {
                                text: qsTr("Manage Lists")
                                onClicked: pageStack.push(Qt.resolvedUrl("../ListManagePage.qml"))
                                visible: (sectionPane.sectionKey === "posts")
                            }
                            MenuItem {
                                text: qsTr("Settings")
                                onClicked: pageStack.push(Qt.resolvedUrl("../SettingsPage.qml"))
                                visible: (sectionPane.sectionKey === "posts")
                            }
                            MenuItem {
                                text: qsTr("Refresh")
                                onClicked: {
                                    if (sectionPane.sectionKey === "posts")
                                        profileView.loadProfile()
                                    sectionPane.load(true)
                                }
                            }
                        }

                        function checkLoadMore() {
                            if (!sectionPane.busy && sectionPane.content.nextCursor.length > 0
                                && sectionPane.content.nextCursor !== sectionPane.content.lastLoadMoreCursor && atYEnd) {
                                sectionPane.content.lastLoadMoreCursor = sectionPane.content.nextCursor
                                sectionPane.load(false)
                            }
                        }
                        onAtYEndChanged: checkLoadMore()
                        onMovementEnded: checkLoadMore()

                        delegate: PostDelegate {}

                        VerticalScrollDecorator {}

                        ViewPlaceholder {
                            enabled: !sectionPane.busy && innerList.count === 0
                                && sectionPane.errorText.length === 0
                            text: qsTr("Nothing here yet")
                        }

                        ViewPlaceholder {
                            enabled: sectionPane.errorText.length > 0
                            text: qsTr("Couldn't load")
                            hintText: sectionPane.errorText
                        }
                    }

                    BusyIndicator {
                        anchors.centerIn: parent
                        running: sectionPane.busy && innerList.count === 0
                        visible: running
                        size: BusyIndicatorSize.Large
                    }

                    BusyIndicator {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: parent.top
                            topMargin: Theme.paddingMedium
                        }
                        running: sectionPane.busy && innerList.count > 0
                        visible: running
                        size: BusyIndicatorSize.Small
                    }
                }

                onCurrentIndexChanged: {
                    if (tabStrip.currentIndex !== currentIndex)
                        tabStrip.currentIndex = currentIndex

                    profileView.stripHidden = false
                    tabStripPanel.show()
                }
            }

            DockedPanel {
                id: tabStripPanel
                width: parent.width
                height: tabStrip.height
                dock: Dock.Top
                open: true
                background: null

                FeedTabStrip {
                    id: tabStrip
                    width: parent.width
                    isPortrait: profileView.isPortrait
                    model: sectionsModel
                    onCurrentIndexChanged: {
                        if (slideshow.currentIndex !== currentIndex)
                            slideshow.currentIndex = currentIndex
                    }
                }
            }
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: !profileView.profileReady && profileView.errorText.length === 0
        visible: running
        size: BusyIndicatorSize.Large
    }

    ViewPlaceholder {
        anchors.fill: parent
        enabled: !profileView.profileReady && profileView.errorText.length > 0
        text: qsTr("Couldn't load profile")
        hintText: profileView.errorText
    }
}
