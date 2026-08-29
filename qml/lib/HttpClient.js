.pragma library

// Generic JSON-over-XHR request. Used both for authenticated Mastodon API
// calls (SessionManager.js wraps this, adding the Authorization header)
// and FirstPage.qml's pre-login app-registration call (no auth header
// exists yet at that point).
//
// method: "GET"|"POST"|"PUT"|"DELETE"
// url: full URL (caller already joined instanceUrl + path)
// headers: plain object of extra header name -> value, or null/{} for none.
//   Content-Type: application/json is added automatically whenever body is
//   non-null - callers don't set it themselves.
// body: plain JS object (JSON-encoded) or null for a body-less call
// onSuccess(parsedJsonOrNull, linkHeader) - response is null if the 200
//   body failed to parse as JSON (guarded, never throws); linkHeader is the
//   raw Link response header (Mastodon's cursor-pagination header), or ""
//   when absent/inaccessible.
// onFailure(status, message) - message is the server's JSON `.error` field
//   if present, else statusText, else a generic network-error string.
// logPrefix: optional tag (e.g. "[Session]") prepended to this module's own
//   diagnostic console output, so failures stay traceable to their caller.
function request(method, url, headers, body, onSuccess, onFailure, logPrefix) {
    var prefix = logPrefix || "[Http]"
    var xhr = new XMLHttpRequest()
    xhr.open(method, url)
    for (var h in (headers || {}))
        xhr.setRequestHeader(h, headers[h])
    if (body)
        xhr.setRequestHeader("Content-Type", "application/json")

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return

        if (xhr.status === 200) {
            var response = null
            try {
                response = JSON.parse(xhr.responseText)
            } catch (e) {
                console.warn(prefix, "failed to parse response JSON:", e)
            }
            var linkHeader = ""
            try {
                linkHeader = xhr.getResponseHeader("Link") || ""
            } catch (e) {
                // some backends/xhr shims throw on a missing header instead
                // of just returning null - treat identically to absent
            }
            onSuccess(response, linkHeader)
            return
        }

        var errorMessage = ""
        try {
            var parsed = JSON.parse(xhr.responseText)
            errorMessage = parsed.error || ""
        } catch (e) {
            // responseText wasn't JSON - errorMessage stays empty, handled below
        }

        console.warn(prefix, "request failed, status:", xhr.status, url)
        onFailure(xhr.status, errorMessage.length > 0 ? errorMessage : xhr.statusText)
    }

    xhr.onerror = function() {
        console.error(prefix, "xhr transport error:", url)
        onFailure(0, "Network error")
    }

    xhr.send(body ? JSON.stringify(body) : undefined)
}
