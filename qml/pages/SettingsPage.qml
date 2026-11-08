import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager

// Settings overview: one row per category. New categories (posting
// defaults, notifications, filters...) are added as further rows.

AppPage {
    id: settingsPage

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Settings")
            }

            SettingsEntry {
                title: qsTr("Appearance")
                subtitle: qsTr("Presets, fonts and colors")
                onClicked: pageStack.push(Qt.resolvedUrl("AppearanceSettingsPage.qml"))
            }

            SettingsEntry {
                title: qsTr("Reading and content")
                subtitle: qsTr("Emoji and GIFs")
                onClicked: pageStack.push(Qt.resolvedUrl("ReadingSettingsPage.qml"))
            }

            SectionHeader { text: qsTr("Account") }

            SettingsEntry {
                title: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }

            SettingsEntry {
                title: qsTr("Log out")
                chevron: false
                onClicked: {
                    Remorse.popupAction(settingsPage, qsTr("Logging out"), function() {
                        SessionManager.clearSession()
                        pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
                    })
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
