import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"

AppPage {
    id: sectionPickerPage

    property string currentSection: "posts"

    signal sectionSelected(string section)

    SilicaListView {
        anchors.fill: parent

        header: PageHeader {
            title: qsTr("View")
        }

        model: ListModel {
            ListElement { key: "posts";   label: qsTr("Posts")}
            //ListElement { key: "replies"; label: qsTr("Replies") }
            //ListElement { key: "media";   label: qsTr("Media") }
            //ListElement { key: "videos";  label: qsTr("Videos") }
            ListElement { key: "likes";   label: qsTr("Likes"); }
            //ListElement { key: "lists";   label: qsTr("Lists"); }
            ListElement { key: "bookmarks";   label: qsTr("Bookmarks") }
        }

        delegate: ListItem {
            id: sectionDelegate
            contentHeight: Theme.itemSizeSmall

            onClicked: {
                sectionPickerPage.currentSection = model.key
                sectionPickerPage.sectionSelected(model.key)
            }

            AppLabel {
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                text: model.label
                font.bold: model.key === sectionPickerPage.currentSection
                color: model.key === sectionPickerPage.currentSection
                    ? palette.highlightColor
                    : (model.implemented ? Theme.primaryColor : Theme.secondaryColor)
            }

        }

        VerticalScrollDecorator {}
    }
}
