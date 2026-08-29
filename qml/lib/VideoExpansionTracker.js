.pragma library

// Lets PostDelegate.qml's video Item (many component-boundaries away from
// MainPage.qml, and never a single instance - multiple PostDelegate/FeedPane
// instances can exist at once) tell MainPage.qml whether any video anywhere
// is currently expanded full-width, so it can hide the tab bar. A plain
// module-level var wouldn't be enough on its own - like every other shared
// module in this app, its state isn't itself bindable in QML - so this
// exposes an explicit subscribe/notify callback instead, same idea as
// FeedsManager.loadFeeds(callback), just for a persistent subscription
// rather than a one-time completion.
var expandedCount = 0
var listeners = []

function videoExpanded() {
    expandedCount++
    _notify()
}

function videoCollapsed() {
    expandedCount = Math.max(0, expandedCount - 1)
    _notify()
}

function subscribe(callback) {
    listeners.push(callback)
}

function _notify() {
    var anyExpanded = expandedCount > 0
    for (var i = 0; i < listeners.length; i++)
        listeners[i](anyExpanded)
}
