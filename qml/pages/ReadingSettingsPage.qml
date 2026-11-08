import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib" as AppLib

AppPage {
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Reading and content")
            }

            SettingsSwitch {
                width: parent.width
                text: qsTr("Colorful emoji")
                description: qsTr("Show custom and standard emoji as images instead of text.")
                manager: AppLib.EmojiManager
                key: "renderEmojis"
                setter: "selectRenderEmojis"
            }

            SettingsSwitch {
                width: parent.width
                text: qsTr("Autoplay GIFs")
                description: qsTr("Play GIFs as they scroll into view.")
                manager: AppLib.VideoManager
                key: "autoplayGifs"
                setter: "selectAutoplayGifs"
            }
        }

        VerticalScrollDecorator {}
    }
}
