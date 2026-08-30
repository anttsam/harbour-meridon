.pragma library
.import "TokenStorage.js" as TokenStorage
.import "HttpClient.js" as HttpClient

// In-memory session state, shared across every QML file that imports this
// module within the same engine (that's how .pragma library scripts work -
// one shared instance, not a fresh copy per importer).
var current = null // { accessToken, instanceUrl, accountId, username }

function setSession(session) {
    current = session
}

function getSession() {
    return current
}

function getCurrentUserId() {
    return current ? current.accountId : ""
}

// Lets other modules react to logout without a circular .import back
// from here - same one-callback pattern as FeedsManager's dirty-listener.
var _logoutListener = null

function onLogout(fn) {
    _logoutListener = fn
}

function clearSession() {
    current = null
    TokenStorage.clearSession()
    if (_logoutListener)
        _logoutListener()
}

function isLoggedIn() {
    return current !== null && current.accessToken && current.accessToken.length > 0
}

// Restores the session from disk into memory. Call this once on app
// startup before anything else touches getSession(). Returns true if a
// session was found.
function restore() {
    var stored = TokenStorage.loadSession()
    if (stored) {
        current = {
            accessToken: stored.accessToken,
            instanceUrl: stored.instanceUrl,
            accountId: stored.accountId,
            username: stored.username
        }
        return true
    }
    return false
}

// Generic authenticated Mastodon REST call.
// method: "GET", "POST", "PUT", or "DELETE"
// path: e.g. "/api/v1/timelines/home?limit=40"
// body: plain JS object (will be JSON-encoded) or null for a body-less call
// onSuccess(parsedJson, linkHeader) - linkHeader is the raw Link response
//   header (for cursor-less pagination via rel="next"/"prev" max_id/min_id),
//   or "" when absent.
// onFailure(status, message)
function authenticatedRequest(method, path, body, onSuccess, onFailure) {
    if (!current) {
        onFailure(0, "Not logged in")
        return
    }

    // A revoked/invalid Mastodon access token has no refresh path - unlike
    // AT Proto's short-lived JWTs, standard Doorkeeper-issued OAuth2 tokens
    // don't expire on their own, so there's nothing to proactively refresh
    // here. Callers already redirect to FirstPage.qml on a 401
    // (session-expired) at every call site.
    var headers = { "Authorization": "Bearer " + current.accessToken }
    HttpClient.request(method, current.instanceUrl + path, headers, body,
        onSuccess, onFailure, "[Session]")
}

// Media upload (POST /api/v2/media) deliberately isn't implemented here -
// it's the one call in this app that needs a binary POST body, and QML's
// own XMLHttpRequest can't produce one on this platform: ArrayBuffer
// support for XMLHttpRequest.send() only landed in Qt 5.10 (QTBUG-61599),
// and SailfishOS 5.1 ships Qt 5.6.3, where passing one silently
// stringifies it instead. See src/mediauploader.cpp (a native
// QNetworkAccessManager/QHttpMultiPart uploader exposed to QML as
// MediaUploader) and its use in ComposePage.qml.

// Runs immediately when this module is first imported - .pragma library
// scripts evaluate exactly once, and critically, that happens while the
// importing QML file (MainPage.qml) is still being parsed, strictly
// before any of its child items get constructed. Putting this call
// inside MainPage's own Component.onCompleted instead was too late:
// QML fires Component.onCompleted bottom-up (children before parent), so
// TimelineView's onCompleted (which calls load(true)) was firing before
// MainPage's ever did, attempting a fetch with no session loaded at all.
restore()
