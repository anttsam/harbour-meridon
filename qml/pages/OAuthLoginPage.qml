import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.WebView 1.0
import Amber.Web.Authorization 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager
import "../lib/TokenStorage.js" as TokenStorage

AppPage {
    id: oauthPage

    // Set by FirstPage.qml before pushing this page.
    property string instanceUrl: ""   // e.g. "https://mastodon.social"
    property string clientId: ""
    property string clientSecret: ""

    property bool verifying: false
    property string errorText: ""

    readonly property int redirectPort: 47623

    OAuth2Ac {
        id: oauth
        authorizationEndpoint: oauthPage.instanceUrl + "/oauth/authorize"
        tokenEndpoint: oauthPage.instanceUrl + "/oauth/token"
        clientId: oauthPage.clientId
        clientSecret: oauthPage.clientSecret
        scopes: ["read", "write", "follow"]
        redirectListener.port: oauthPage.redirectPort

        onReceivedAccessToken: {
            var accessToken = token.access_token
            if (!accessToken) {
                oauthPage.errorText = qsTr("Instance didn't return an access token")
                return
            }

            oauthPage.verifying = true

            // Set a provisional session
            SessionManager.setSession({
                accessToken: accessToken,
                instanceUrl: oauthPage.instanceUrl,
                accountId: "",
                username: ""
            })

            SessionManager.authenticatedRequest("GET", "/api/v1/accounts/verify_credentials", null,
                function(response) {
                    oauthPage.verifying = false
                    SessionManager.setSession({
                        accessToken: accessToken,
                        instanceUrl: oauthPage.instanceUrl,
                        accountId: response.id,
                        username: response.username
                    })
                    TokenStorage.saveSession(accessToken, oauthPage.instanceUrl,
                        response.id, response.username)
                    console.log("[OAuth] logged in as", response.username, "on", oauthPage.instanceUrl)
                    pageStack.animatorReplace(Qt.resolvedUrl("MainPage.qml"))
                },
                function(status, message) {
                    oauthPage.verifying = false
                    SessionManager.clearSession()
                    console.warn("[OAuth] verify_credentials failed:", status, message)
                    oauthPage.errorText = qsTr("Login failed: %1").arg(message)
                })
        }

        onErrorOccurred: {
            console.warn("[OAuth] error:", JSON.stringify(error))
            oauthPage.errorText = error.message || qsTr("Authorization failed")
        }
    }

    Component.onCompleted: {
        webView.url = oauth.authorizationUrl()
    }

    Item {
        id: header
        width: parent.width
        height: Theme.itemSizeLarge

        AppLabel {
            anchors {
                left: parent.left
                leftMargin: Theme.horizontalPageMargin
                verticalCenter: parent.verticalCenter
                right: parent.right
                rightMargin: Theme.horizontalPageMargin
            }
            text: oauthPage.instanceUrl.replace(/^https?:\/\//, "")
            font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
            truncationMode: TruncationMode.Fade
            color: Theme.secondaryColor
        }
    }

    WebView {
        id: webView
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba(Theme.overlayBackgroundColor, 0.9)
        visible: oauthPage.verifying

        BusyIndicator {
            anchors.centerIn: parent
            running: oauthPage.verifying
            size: BusyIndicatorSize.Large
        }
    }

    AppLabel {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: Theme.horizontalPageMargin
        }
        wrapMode: Text.Wrap
        color: Theme.highlightColor
        visible: oauthPage.errorText.length > 0
        text: oauthPage.errorText
    }
}
