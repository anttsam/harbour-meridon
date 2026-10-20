.pragma library

// Lets ComposePage.qml tell the persistent ProfileView in MainPage (a
// different page, nowhere near it) that something was just posted or edited,
// so it can refresh the user's own posts. Same explicit subscribe/notify idea
// as VideoExpansionTracker.js, since module state isn't bindable in QML.
var listeners = []

function subscribe(callback) {
    listeners.push(callback)
}

function unsubscribe(callback) {
    var i = listeners.indexOf(callback)
    if (i !== -1)
        listeners.splice(i, 1)
}

function posted() {
    for (var i = 0; i < listeners.length; i++) {
        try {
            listeners[i]()
        } catch (e) {
            console.warn("[PostEvents] listener failed:", e)
        }
    }
}
