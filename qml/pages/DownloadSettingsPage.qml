import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import harbour.meridon.Native 1.0
import "components"
import "../lib" as AppLib

AppPage {
    id: downloadSettingsPage

    readonly property bool customFolder: AppLib.DownloadManager.imagePath.length > 0
    readonly property string currentFolder: customFolder ? AppLib.DownloadManager.imagePath
                                                         : imageSaver.defaultDirectory()

    // Only used to ask where the default folder is
    ImageSaver { id: imageSaver }

    Component {
        id: folderPickerComponent

        FolderPickerPage {
            dialogTitle: qsTr("Image folder")
            onSelectedPathChanged: {
                if (selectedPath.length > 0)
                    AppLib.DownloadManager.selectImagePath(selectedPath)
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Downloads")
            }

            ValueButton {
                width: parent.width
                label: qsTr("Image folder")
                value: downloadSettingsPage.currentFolder
                description: qsTr("Pictures saved from the image viewer go here.")
                onClicked: pageStack.animatorPush(folderPickerComponent)
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: downloadSettingsPage.customFolder
                text: qsTr("Use default folder")
                onClicked: AppLib.DownloadManager.selectImagePath("")
            }
        }

        VerticalScrollDecorator {}
    }
}
