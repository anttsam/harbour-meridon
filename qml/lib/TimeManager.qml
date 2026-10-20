pragma Singleton
import QtQuick 2.0

// Shared tick so relative timestamps ("5m", "2h") can be re-evaluated
// without refetching the posts they belong to. Bumped by whoever just
// refreshed something, and automatically when the app comes back to the
// foreground - deliberately not on a timer.
QtObject {
    id: timeManager

    property int tick: 0

    function bump() {
        timeManager.tick++
    }

    property bool appActive: Qt.application.active
    onAppActiveChanged: {
        if (appActive)
            bump()
    }
}
