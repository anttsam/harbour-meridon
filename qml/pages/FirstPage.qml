import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager
import "../lib/InstanceAppStorage.js" as InstanceAppStorage
import "../lib/HttpClient.js" as HttpClient

AppPage {
    id: firstPage

    property bool busy: false
    property string errorText: ""

    readonly property string redirectUri: "http://127.0.0.1:47623/"

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Log in to Mastodon")
            }

            AppLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                text: qsTr("Enter the domain of your Mastodon server. "
                    + "You'll log in and authorize this app on the server's own page.")
            }

            TextField {
                id: instanceField
                width: parent.width
                label: qsTr("Server")
                placeholderText: qsTr("mastodon.social")
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: firstPage.attemptContinue()
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly
                validator: RegExpValidator { regExp: /.+/ }
            }

            Item {
                width: parent.width
                height: Theme.itemSizeSmall

                BusyIndicator {
                    anchors.centerIn: parent
                    running: firstPage.busy
                    visible: firstPage.busy
                    size: BusyIndicatorSize.Medium
                }

                Button {
                    anchors.centerIn: parent
                    visible: !firstPage.busy
                    text: qsTr("Continue")
                    enabled: instanceField.text.length > 0
                    onClicked: firstPage.attemptContinue()
                }
            }

            AppLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                visible: errorText.length > 0
                text: errorText
            }
        }
    }

    // Strips any scheme/path/trailing-slash
    function normalizeDomain(input) {
        var d = input.trim()
        d = d.replace(/^https?:\/\//, "")
        d = d.replace(/^@/, "")
        // "user@domain" - keep only the domain part, if someone pastes a handle
        var atIndex = d.indexOf("@")
        if (atIndex >= 0)
            d = d.substring(atIndex + 1)
        d = d.replace(/\/.*$/, "")
        return d
    }

    function attemptContinue() {
        if (busy)
            return

        errorText = ""
        var domain = normalizeDomain(instanceField.text)
        if (domain.length === 0) {
            errorText = qsTr("Enter a server address")
            return
        }

        var instanceUrl = "https://" + domain
        var cached = InstanceAppStorage.loadApp(domain)
        if (cached) {
            console.log("[FirstPage] using cached app registration for", domain)
            openOAuthPage(instanceUrl, cached.clientId, cached.clientSecret)
            return
        }

        busy = true
        console.log("[FirstPage] registering app with", domain)

        HttpClient.request("POST", instanceUrl + "/api/v1/apps", null, {
            client_name: "Meridon",
            redirect_uris: firstPage.redirectUri,
            scopes: "read write follow"
        }, function(response, linkHeader) {
            busy = false
            console.log("[FirstPage] app registered, client_id:", response.client_id)
            InstanceAppStorage.saveApp(domain, response.client_id, response.client_secret)
            openOAuthPage(instanceUrl, response.client_id, response.client_secret)
        }, function(status, message) {
            busy = false
            console.warn("[FirstPage] app registration failed, status:", status, "message:", message)
            errorText = status === 0
                ? qsTr("Couldn't reach that server")
                : qsTr("Couldn't reach that server: %1").arg(message)
        }, "[FirstPage]")
    }

    function openOAuthPage(instanceUrl, clientId, clientSecret) {
        pageStack.push(Qt.resolvedUrl("OAuthLoginPage.qml"), {
            instanceUrl: instanceUrl,
            clientId: clientId,
            clientSecret: clientSecret
        })
    }
}
