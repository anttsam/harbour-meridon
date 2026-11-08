import QtQuick 2.0
import Sailfish.Silica 1.0

// ComboBox kept in two-way sync with a string key property of a manager
// singleton, see SettingsSwitch.qml. keys are the values the manager
// stores, labels what the menu shows. fontFamilies (optional, one per
// entry) previews each entry in its own font.

ComboBox {
    id: root

    property var manager
    property string key
    property string setter
    property var keys: []
    property var labels: []
    property var fontFamilies: null
    property int fontWeight: Font.Normal

    width: parent ? parent.width : implicitWidth

    menu: ContextMenu {
        Repeater {
            model: root.labels
            MenuItem {
                text: modelData
                font.family: root.fontFamilies ? root.fontFamilies[index] : Theme.fontFamily
                font.weight: root.fontFamilies ? root.fontWeight : Font.Normal
            }
        }
    }

    onCurrentIndexChanged: {
        if (currentIndex >= 0 && manager && manager[key] !== keys[currentIndex])
            manager[setter](keys[currentIndex])
    }

    Binding {
        target: root
        property: "currentIndex"
        value: root.manager ? root.keys.indexOf(root.manager[root.key]) : -1
    }
}
