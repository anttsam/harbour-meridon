import QtQuick 2.0
import Sailfish.Silica 1.0

// A TextSwitch kept in two-way sync with a boolean property of a manager
// singleton: manager[key] is shown, manager[setter](checked) is called on a
// user toggle. The Binding re-applies the manager's value whenever it
// changes (also from elsewhere, e.g. a preset being applied), which a plain
// "checked: ..." binding wouldn't survive the first tap.

TextSwitch {
    id: root

    property var manager
    property string key
    property string setter

    onCheckedChanged: {
        if (manager && manager[key] !== checked)
            manager[setter](checked)
    }

    Binding {
        target: root
        property: "checked"
        value: root.manager ? root.manager[root.key] : false
    }
}
