import QtQuick 2.0
import Sailfish.Silica 1.0

// Watches a Flickable's contentY while the user is actively dragging it and
// reports which direction they're scrolling, for driving MainPage's
// hide-on-scroll-down/show-on-scroll-up tab bar.

Item {
    id: tracker

    property Flickable target
    property bool hidden: false

    property real _lastToggleY: 0

    // SilicaListView.scrollToTop(), donsnt "drag", so recover and show
    function reset() {
        hidden = false
        _lastToggleY = target ? target.contentY : 0
    }

    Connections {
        target: tracker.target
        ignoreUnknownSignals: true

        onContentYChanged: {
            if (!tracker.target || !tracker.target.dragging)
                return

            var y = tracker.target.contentY
            if (y <= 0) {
                // Always show once scrolled back to the very top
                tracker.hidden = false
                tracker._lastToggleY = y
            } else if (Math.abs(y - tracker._lastToggleY) > Theme.itemSizeMedium) {
                tracker.hidden = (y - tracker._lastToggleY > 0) // scrolled down -> hide
                tracker._lastToggleY = y
            }
        }

        // just reset if top
        onQuickScrollAnimatingChanged: {
            if (tracker.target && !tracker.target.quickScrollAnimating && tracker.target.contentY <= 0)
                tracker.reset()
        }
    }
}
