import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager

// Mastodon's GET /api/v1/trends/tags
AppPage {
    id: page

    property bool busy: false
    property string errorText: ""

    ListModel {
        id: tagsModel
    }

    function weeklyUses(history) {
        var total = 0
        for (var i = 0; i < (history || []).length; i++)
            total += parseInt(history[i].uses, 10) || 0
        return total
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: tagsModel

        header: PageHeader {
            title: qsTr("Trending Hashtags")
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: page.load()
            }
        }

        delegate: ListItem {
            id: tagDelegate
            contentHeight: Theme.itemSizeSmall

            onClicked: pageStack.push(Qt.resolvedUrl("HashtagPage.qml"), {
                hashtag: model.name
            })

            AppLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                text: "#" + model.name
                truncationMode: TruncationMode.Fade
                font.pixelSize: (Theme.fontSizeMedium) * sizeMultiplier
            }

            Label {
                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                text: qsTr("%1 posts").arg(model.uses)
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: !page.busy && tagsModel.count === 0 && errorText.length === 0
            text: qsTr("Nothing trending")
            hintText: qsTr("Check back later")
        }

        ViewPlaceholder {
            enabled: errorText.length > 0 && tagsModel.count === 0
            text: qsTr("Couldn't load")
            hintText: errorText
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: page.busy && tagsModel.count === 0
        visible: running
        size: BusyIndicatorSize.Large
    }

    Component.onCompleted: load()

    function load() {
        if (busy)
            return

        busy = true
        errorText = ""

        SessionManager.authenticatedRequest("GET", "/api/v1/trends/tags?limit=20", null,
            function(response) {
                busy = false
                tagsModel.clear()
                var tags = response || []
                for (var i = 0; i < tags.length; i++) {
                    tagsModel.append({
                        name: tags[i].name,
                        uses: page.weeklyUses(tags[i].history)
                    })
                }
            },
            function(status, message) {
                busy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
                } else {
                    errorText = qsTr("Couldn't load trending hashtags (%1)").arg(message || status)
                }
            }
        )
    }
}
