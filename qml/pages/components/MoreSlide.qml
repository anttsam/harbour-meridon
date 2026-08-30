import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib/SessionManager.js" as SessionManager
import "../../lib/PinnedFeedsStorage.js" as PinnedFeedsStorage

// The carousel's permanent "More" slide: lists/hashtags hidden from the
// Home header, a way back into Lists & Hashtags management, and Mastodon's
// Explore endpoints (trending posts/hashtags/links, suggested accounts) as
// a discovery jumping-off point.
Item {
    id: moreSlide

    property bool busy: false

    readonly property var recommendedFeeds: [
        { label: qsTr("Posts"), page: "../TrendingPostsPage.qml" },
        { label: qsTr("Hashtags"), page: "../TrendingHashtagsPage.qml" },
        { label: qsTr("News"), page: "../TrendingLinksPage.qml" },
        { label: qsTr("For You"), page: "../SuggestedAccountsPage.qml" }
    ]

    ScrollDirectionTracker {
        id: scrollTracker
        target: flickable
    }
    property alias tabBarHidden: scrollTracker.hidden

    ListModel {
        id: hiddenModel
    }

    SilicaFlickable {
        id: flickable
        anchors.fill: parent
        contentHeight: contentColumn.height

        Column {
            id: contentColumn
            width: parent.width

            SectionHeader {
                text: qsTr("Hidden from header")
                visible: hiddenModel.count > 0
            }

            Repeater {
                model: hiddenModel

                ListItem {
                    width: contentColumn.width
                    contentHeight: Theme.itemSizeSmall

                    onClicked: {
                        if (model.kind === "hashtag")
                            pageStack.push(Qt.resolvedUrl("../HashtagPage.qml"), {
                                hashtag: model.itemId
                            })
                        else
                            pageStack.push(Qt.resolvedUrl("../ListFeedPage.qml"), {
                                listId: model.itemId,
                                listTitle: model.title
                            })
                    }

                    AppLabel {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.title
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: (Theme.fontSizeMedium) * sizeMultiplier
                        useCustomFont: true
                    }
                }
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }

            SectionHeader {
                text: qsTr("Explore")
            }

            Repeater {
                model: moreSlide.recommendedFeeds

                ListItem {
                    width: contentColumn.width
                    contentHeight: Theme.itemSizeSmall

                    onClicked: pageStack.push(Qt.resolvedUrl(modelData.page))

                    AppLabel {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.pixelSize: (Theme.fontSizeMedium) * sizeMultiplier
                        useCustomFont: true
                    }
                }
            }
            Item {
                width: 1
                height: Theme.paddingLarge
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Edit Lists")
                onClicked: pageStack.push(Qt.resolvedUrl("../ListManagePage.qml"))
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: loadHidden()

    function loadHidden() {
        if (busy)
            return
        busy = true

        var hiddenLists = null
        var hiddenHashtags = null
        var pending = 2

        function finish() {
            if (pending > 0)
                return

            busy = false
            hiddenModel.clear()
            ;(hiddenLists || []).forEach(function(row) { hiddenModel.append(row) })
            ;(hiddenHashtags || []).forEach(function(row) { hiddenModel.append(row) })
        }

        SessionManager.authenticatedRequest("GET", "/api/v1/lists", null,
            function(response) {
                var dismissedIds = PinnedFeedsStorage.getDismissedListIds()
                hiddenLists = (response || [])
                    .filter(function(l) { return dismissedIds[l.id] === true })
                    .map(function(l) {
                        return { kind: "list", itemId: l.id, title: l.title || qsTr("Untitled list") }
                    })
                pending -= 1
                finish()
            },
            function(status, message) {
                console.warn("[MoreSlide] loading lists failed:", status, message)
                hiddenLists = []
                pending -= 1
                finish()
            }
        )

        SessionManager.authenticatedRequest("GET", "/api/v1/followed_tags?limit=40", null,
            function(response) {
                var dismissedHashtagIds = PinnedFeedsStorage.getDismissedHashtagIds()
                hiddenHashtags = (response || [])
                    .filter(function(t) { return dismissedHashtagIds[t.name] === true })
                    .map(function(t) {
                        return { kind: "hashtag", itemId: t.name, title: "#" + t.name }
                    })
                pending -= 1
                finish()
            },
            function(status, message) {
                console.warn("[MoreSlide] loading followed hashtags failed:", status, message)
                hiddenHashtags = []
                pending -= 1
                finish()
            }
        )
    }

    function scrollToTop() {
        flickable.scrollToTop()
        scrollTracker.reset()
    }
}
