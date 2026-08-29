import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager

AppPage {
    id: listPickerPage

    // The account being added - passed in from wherever this is opened.
    property string subjectDid: ""
    property string subjectName: ""

    property bool busy: false
    property string errorText: ""

    signal listPicked(var list)

    ListModel {
        id: listsModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: listsModel

        header: PageHeader {
            title: qsTr("Add to List")
            description: listPickerPage.subjectName.length > 0
                ? qsTr("Adding %1").arg(listPickerPage.subjectName) : ""
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: listPickerPage.load()
            }
        }

        delegate: ListItem {
            id: listDelegate
            contentHeight: Theme.itemSizeMedium

            onClicked: {
                listPickerPage.listPicked({
                    id: model.listId,
                    name: model.name
                })
                pageStack.pop()
            }

            Row {
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                // Mastodon Lists have no avatar/icon
                Image {
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    anchors.verticalCenter: parent.verticalCenter
                    source: "image://theme/icon-m-file-note"
                }

                AppLabel {
                    width: parent.width - Theme.iconSizeMedium - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: model.name
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: (Theme.fontSizeMedium) * sizeMultiplier
                }
            }
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: !listPickerPage.busy && listsModel.count === 0 && errorText.length === 0
            text: qsTr("No lists yet")
            hintText: qsTr("Create one from Lists in your profile first")
        }

        ViewPlaceholder {
            enabled: errorText.length > 0 && listsModel.count === 0
            text: qsTr("Couldn't load lists")
            hintText: errorText
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: listPickerPage.busy && listsModel.count === 0
        visible: running
        size: BusyIndicatorSize.Large
    }

    Component.onCompleted: load()

    function load() {
        if (busy)
            return

        busy = true
        errorText = ""

        // Mastodon has no moderation-list
        SessionManager.authenticatedRequest("GET", "/api/v1/lists", null,
            function(response) {
                busy = false
                listsModel.clear()
                var lists = response || []
                for (var i = 0; i < lists.length; i++) {
                    listsModel.append({
                        listId: lists[i].id,
                        name: lists[i].title
                    })
                }
            },
            function(status, message) {
                busy = false
                if (status === 401) {
                    SessionManager.clearSession()
                    pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
                } else {
                    errorText = qsTr("Couldn't load lists (%1)").arg(message || status)
                }
            }
        )
    }
}
