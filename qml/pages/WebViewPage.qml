import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.WebView 1.0
import "components"
import "../lib/PostMapper.js" as PostMapper

WebViewPage {
    id: webViewPage

    property string url: ""

    Item {
        id: header
        width: parent.width
        height: Theme.itemSizeLarge

        AppLabel {
            anchors {
                left: parent.left
                leftMargin: Theme.horizontalPageMargin
                verticalCenter: parent.verticalCenter
                right: actionRow.left
                rightMargin: Theme.paddingMedium
            }
            text: PostMapper.extractDomain(webViewPage.url)
            font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
            truncationMode: TruncationMode.Fade
            color: Theme.secondaryColor
        }

        Row {
            id: actionRow
            anchors {
                right: parent.right
                rightMargin: Theme.horizontalPageMargin
                verticalCenter: parent.verticalCenter
            }
            spacing: Theme.paddingMedium

            IconButton {
                icon.source: "image://theme/icon-m-refresh"
                onClicked: webView.reload()
            }

            IconButton {
                icon.source: "image://theme/icon-m-website"
                onClicked: Qt.openUrlExternally(webViewPage.url)
            }
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
        url: webViewPage.url
    }

    // WebViewPage already shows its own loading indicator

    Rectangle {
        id: backButtonBackground
        anchors {
            left: parent.left
            bottom: parent.bottom
            margins: Theme.paddingLarge
        }
        width: Theme.iconSizeMedium + Theme.paddingMedium
        height: width
        radius: width / 2
        color: Theme.rgba("black", 0.8)
        opacity: backButton.enabled ? 1.0 : Theme.opacityLow
        Behavior on opacity { FadeAnimation {} }

        IconButton {
            id: backButton
            anchors.centerIn: parent
            //anchors.fill: parent
            scale: 2
            icon.source: "image://theme/icon-splus-left?white"
            enabled: webView.canGoBack
            onClicked: webView.goBack()
        }
    }
}
