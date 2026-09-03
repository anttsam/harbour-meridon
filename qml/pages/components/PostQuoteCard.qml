import QtQuick 2.0
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0

// Preview card for a reposted/quoted status
Item {
    id: quoteCardWrapper

    property var quote: null

    visible: quote !== null
    height: quoteCard.height

    Rectangle {
        id: quoteCard
        width: parent.width
        height: quoteColumn.height + 2 * Theme.paddingMedium
        radius: Theme.paddingSmall
        color: Theme.rgba(Theme.primaryColor, 0.06)
        border.color: Theme.rgba(Theme.primaryColor, 0.15)
        border.width: 1
        visible: false // only rendered as OpacityMask's source below

        Column {
            id: quoteColumn
            y: Theme.paddingMedium
            x: Theme.paddingMedium
            width: parent.width - 2 * Theme.paddingMedium
            spacing: Theme.paddingSmall

            AppLabel {
                width: parent.width
                visible: quoteCardWrapper.quote && quoteCardWrapper.quote.unavailable
                text: quoteCardWrapper.quote ? quoteCardWrapper.quote.text : ""
                font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                color: Theme.secondaryColor
                font.italic: true
                useCustomFont: true
            }

            Row {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: quoteCardWrapper.quote && !quoteCardWrapper.quote.unavailable

                RoundedAvatar {
                    size: Theme.iconSizeExtraSmall
                    source: (!quoteCardWrapper.quote || quoteCardWrapper.quote.authorAvatar.length === 0)
                        ? "image://theme/icon-m-contact" : quoteCardWrapper.quote.authorAvatar
                }

                AppLabel {
                    text: quoteCardWrapper.quote ? (quoteCardWrapper.quote.authorName || quoteCardWrapper.quote.authorHandle) : ""
                    font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                    bold: true
                    truncationMode: TruncationMode.Fade
                    width: parent.width - Theme.iconSizeExtraSmall - parent.spacing
                    useCustomFont: true
                }
            }

            AppLabel {
                width: parent.width
                visible: quoteCardWrapper.quote && !quoteCardWrapper.quote.unavailable
                text: quoteCardWrapper.quote ? quoteCardWrapper.quote.text : ""
                wrapMode: Text.Wrap
                maximumLineCount: 4
                truncationMode: TruncationMode.Fade
                font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                color: Theme.primaryColor
                useCustomFont: true
            }

            Image {
                width: Theme.itemSizeHuge
                height: Theme.itemSizeHuge
                visible: quoteCardWrapper.quote && quoteCardWrapper.quote.thumbUrl && quoteCardWrapper.quote.thumbUrl.length > 0
                source: quoteCardWrapper.quote ? quoteCardWrapper.quote.thumbUrl : ""
                fillMode: Image.PreserveAspectCrop
                clip: true
                asynchronous: true
                sourceSize.width: width
                sourceSize.height: height
            }
        }
    }

    // make card corners round and render the card
    Rectangle {
        id: quoteCardMask
        anchors.fill: quoteCard
        radius: Theme.paddingSmall
        visible: false
    }

    OpacityMask {
        anchors.fill: quoteCard
        source: quoteCard
        maskSource: quoteCardMask
    }

    // steel mouse to target the full card
    MouseArea {
        anchors.fill: quoteCard
        enabled: quoteCardWrapper.quote && !quoteCardWrapper.quote.unavailable
        onClicked: pageStack.push(Qt.resolvedUrl("../PostDetailPage.qml"), {
            postUri: quoteCardWrapper.quote.uri
        })
    }
}
