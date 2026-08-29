import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/LinkHandler.js" as LinkHandler

AppPage {
    id: aboutPage

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("About")
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.iconSizeLarge * 1.5
                height: width
                source: Qt.resolvedUrl("../images/harbour-meridon.png")
                smooth: true
                asynchronous: true
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                AppLabel {
                    useCustomFont: true
                    text: "Meridon"
                    bold: true
                    font.pixelSize: (Theme.fontSizeExtraLarge) * sizeMultiplier
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: palette.secondaryHighlightColor
                }

                AppLabel {
                    useCustomFont: true
                    text: qsTr("Version %1").arg("1.0")
                    color: palette.secondaryHighlightColor
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Item {
                    width: 1
                    height: Theme.itemSizeSmall
                }

                AppLabel {
                    useCustomFont: true
                    width: parent.width
                    text: qsTr("A native Mastodon client for SailfishOS. Supports most of the Mastodon features such as lists as well as some basic Sailfish OS theming.")
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                AppLabel {
                    useCustomFont: true
                    id: licenseLink
                    width: parent.width
                    text: qsTr("Licensed under the") + ' <a href="https://www.gnu.org/licenses/gpl-3.0.html">GNU General Public License v3.0</a>'
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    linkColor: palette.secondaryHighlightColor
                    color: Theme.secondaryColor
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                    anchors.horizontalCenter: parent.horizontalCenter

                    MouseArea {
                        anchors.fill: parent
                        onPressed: mouse.accepted = licenseLink.linkAt(mouse.x, mouse.y).length > 0
                        onClicked: {
                            var link = licenseLink.linkAt(mouse.x, mouse.y)
                            if (link.length > 0)
                                LinkHandler.openLink(link, pageStack, null, null)
                        }
                    }
                }
            }

            SectionHeader { text: qsTr("Developers and contributors") }

            AppLabel {
                useCustomFont: true
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "zammy - @anttsam"
                font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                anchors.horizontalCenter: parent.horizontalCenter
            }

            SectionHeader { text: qsTr("Credits") }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingLarge

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall

                    AppLabel {
                        useCustomFont: true
                        width: parent.width
                        text: qsTr("Emoji and flag graphics: Twemoji")
                        wrapMode: Text.Wrap
                        font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                    }

                    AppLabel {
                        useCustomFont: true
                        width: parent.width
                        text: qsTr("Copyright 2019 Twitter, Inc and other contributors. Licensed under CC-BY 4.0.")
                        wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                    }

                    AppLabel {
                        useCustomFont: true
                        id: ccLink
                        width: parent.width
                        text: '<a href="https://creativecommons.org/licenses/by/4.0/">creativecommons.org/licenses/by/4.0</a>'
                        textFormat: Text.StyledText
                        linkColor: palette.secondaryHighlightColor
                        color: Theme.secondaryColor
                        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier

                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse.accepted = ccLink.linkAt(mouse.x, mouse.y).length > 0
                            onClicked: {
                                var link = ccLink.linkAt(mouse.x, mouse.y)
                                if (link.length > 0)
                                    LinkHandler.openLink(link, pageStack, null, null)
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall

                    AppLabel {
                        useCustomFont: true
                        width: parent.width
                        text: qsTr("Fonts: Fira Sans, Inter, Open Sans, Roboto, Ubuntu")
                        wrapMode: Text.Wrap
                        font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                    }

                    AppLabel {
                        useCustomFont: true
                        width: parent.width
                        text: qsTr("Licensed under the SIL Open Font License 1.1.")
                        wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
        }

        VerticalScrollDecorator {}
    }
}
