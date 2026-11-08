import QtQuick 2.0
import Sailfish.Silica 1.0

// Percent slider kept in two-way sync with a numeric property of a manager
// singleton, see SettingsSwitch.qml

Slider {
    id: root

    property var manager
    property string key
    property string setter

    width: parent ? parent.width : implicitWidth
    stepSize: 0.05
    valueText: Math.round(value * 100) + "%"

    // Setting the range or the initial value clamps value before the
    // Binding below has applied the stored one - not the user's doing, so
    // it mustn't be written back
    property bool _ready: false
    Component.onCompleted: _ready = true

    onValueChanged: {
        if (_ready && manager && Math.abs(manager[key] - value) > 0.0001)
            manager[setter](value)
    }

    Binding {
        target: root
        property: "value"
        value: root.manager ? root.manager[root.key] : 0
    }
}
