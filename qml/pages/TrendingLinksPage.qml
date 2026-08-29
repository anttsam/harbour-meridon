import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager
import "../lib/PostMapper.js" as PostMapper

// Mastodon's GET /api/v1/trends/links

AppPage {
    id: page

    property bool busy: false
    property string errorText: ""

    ListModel {
        id: linksModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: linksModel

        header: PageHeader {
            title: qsTr("Trending News")
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: page.load()
            }
        }

        delegate: Item {
            width: listView.width
            height: linkCard.height + Theme.paddingMedium

            PostLinkCard {
                id: linkCard
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                link: ({
                    uri: model.linkUri,
                    title: model.linkTitle,
                    description: model.linkDescription,
                    thumbUrl: model.linkThumbUrl,
                    domain: model.linkDomain
                })
            }
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: !page.busy && linksModel.count === 0 && errorText.length === 0
            text: qsTr("Nothing trending")
            hintText: qsTr("Check back later")
        }

        ViewPlaceholder {
            enabled: errorText.length > 0 && linksModel.count === 0
            text: qsTr("Couldn't load")
            hintText: errorText
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: page.busy && linksModel.count === 0
        visible: running
        size: BusyIndicatorSize.Large
    }

    Component.onCompleted: load()

    function load() {
        if (busy)
            return

        busy = true
        errorText = ""

        SessionManager.authenticatedRequest("GET", "/api/v1/trends/links?limit=20", null,
            function(response) {
                busy = false
                linksModel.clear()
                var links = response || []
                for (var i = 0; i < links.length; i++) {
                    var l = links[i]
                    linksModel.append({
                        linkUri: l.url,
                        linkTitle: l.title || "",
                        linkDescription: l.description || "",
                        linkThumbUrl: l.image || "",
                        linkDomain: PostMapper.extractDomain(l.url)
                    })
                }
            },
            function(status, message) {
                busy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
                } else {
                    errorText = qsTr("Couldn't load trending links (%1)").arg(message || status)
                }
            }
        )
    }
}
