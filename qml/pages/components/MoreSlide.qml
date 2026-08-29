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
        id: hiddenListsModel
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
                visible: hiddenListsModel.count > 0
            }

            Repeater {
                model: hiddenListsModel

                ListItem {
                    width: contentColumn.width
                    contentHeight: Theme.itemSizeSmall

                    onClicked: pageStack.push(Qt.resolvedUrl("../ListFeedPage.qml"), {
                        listId: model.listId,
                        listTitle: model.title
                    })

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

    Component.onCompleted: loadHiddenLists()

    function loadHiddenLists() {
        if (busy)
            return
        busy = true

        SessionManager.authenticatedRequest("GET", "/api/v1/lists", null,
            function(response) {
                busy = false
                var dismissedIds = PinnedFeedsStorage.getDismissedListIds()
                hiddenListsModel.clear()
                var lists = response || []
                for (var i = 0; i < lists.length; i++) {
                    if (dismissedIds[lists[i].id] === true) {
                        hiddenListsModel.append({
                            listId: lists[i].id,
                            title: lists[i].title || qsTr("Untitled list")
                        })
                    }
                }
            },
            function(status, message) {
                busy = false
                console.warn("[MoreSlide] loading lists failed:", status, message)
            }
        )
    }

    function scrollToTop() {
        flickable.scrollToTop()
        scrollTracker.reset()
    }
}
