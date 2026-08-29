import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib

Item {
    id: tabButton

    property string iconSource: ""
    property bool selected: false

    // not used, but maybe used in the future
    property bool decorated: false

    signal clicked

    Rectangle {
        id: decoration
        visible: tabButton.decorated
        anchors.centerIn: parent
        width: (Theme.iconSizeMedium + Theme.paddingMedium) //* 0.6
        height: width
        radius: width / 2 // squircle, matching RoundedAvatar.qml elsewhere
        color: Theme.secondaryColor //"transparent"
        opacity: 0.1
        border.width: 1
        border.color: Theme.secondaryColor
    }

    Image {
        anchors.centerIn: parent
        width: Theme.iconSizeMedium
        height: Theme.iconSizeMedium
        source: tabButton.iconSource + "?"
            + (tabButton.selected ? AppLib.BackgroundManager.activeHighlightColor : Theme.secondaryColor)
    }

    MouseArea {
        anchors.fill: parent
        onPressed: if (tabButton.decorated) {
                         decoration.color == Theme.primaryColor
                   }
        onReleased:if (tabButton.decorated) {
                        decoration.color == Theme.secondaryColor
                   }

        onClicked: tabButton.clicked()
    }

}
