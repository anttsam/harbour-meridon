import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib
import "../../lib/PostMapper.js" as PostMapper
import "../../lib/LinkHandler.js" as LinkHandler

// The banner/avatar/name/stats/bio block

Column {
    id: profileHeader
    width: parent ? parent.width : 0
    spacing: Theme.paddingLarge

    // make it appear nicely when data is here
    opacity: handle.length > 0 ? 1 : 0
    Behavior on opacity { FadeAnimator {} }

    property string did: ""
    property string currentUserDid: ""
    property string displayName: ""
    property string emojisJson: "{}"
    property string handle: ""
    property string avatarUrl: ""
    property string bannerUrl: ""
    property string bio: ""
    property int followersCount: 0
    property int followsCount: 0
    property int postsCount: 0
    property bool isBot: false
    property bool isLocked: false
    property string createdAt: ""
    property var fieldsList: [] // [{name, value, verified_at}, ...]
    property var familiarFollowers: []

    // Only meaningful when did !== currentUserDid
    property bool viewerFollowing: false

    signal followClicked()

    readonly property string joinedYear: profileHeader.createdAt.length > 0
        ? new Date(profileHeader.createdAt).getFullYear().toString() : ""

    function familiarFollowerName(account) {
        return (account.display_name && account.display_name.length > 0)
            ? account.display_name : account.acct
    }

    // format nicely
    readonly property string familiarFollowersText: {
        var accounts = profileHeader.familiarFollowers
        if (accounts.length === 0)
            return ""
        if (accounts.length === 1)
            return qsTr("Followed by %1").arg(familiarFollowerName(accounts[0]))
        if (accounts.length === 2)
            return qsTr("Followed by %1 and %2")
                .arg(familiarFollowerName(accounts[0])).arg(familiarFollowerName(accounts[1]))
        var remaining = accounts.length - 2
        return remaining === 1
            ? qsTr("Followed by %1, %2, and 1 other")
                .arg(familiarFollowerName(accounts[0])).arg(familiarFollowerName(accounts[1]))
            : qsTr("Followed by %1, %2, and %3 others")
                .arg(familiarFollowerName(accounts[0])).arg(familiarFollowerName(accounts[1])).arg(remaining)
    }

    Item {
        id: bannerSection
        width: parent.width
        height: bannerHeight + avatarSize / 3

        property real bannerHeight: Theme.itemSizeHuge * 1.3
        property real avatarSize: Theme.iconSizeLarge * 1.5

        Image {
            width: parent.width
            height: bannerSection.bannerHeight
            source: profileHeader.bannerUrl
            fillMode: Image.PreserveAspectCrop
            clip: true
            visible: profileHeader.bannerUrl.length > 0
            asynchronous: true
            sourceSize.width: width
            sourceSize.height: height
        }



        RoundedAvatar {
            x: Theme.horizontalPageMargin
            y: bannerSection.bannerHeight - size/3*2
            size: bannerSection.avatarSize
            source: profileHeader.avatarUrl
            shadow: true
        }
    }

   // Item { width: 1; height: Theme.paddingSmall }


    Item {
        width: parent.width
        height: nameColumn.height

        Column {
            id: nameColumn
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
                - followButton.width //- Theme.paddingMedium
            AppLabel {
                useCustomFont: true
               // x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin
                text: AppLib.EmojiManager.render(profileHeader.displayName || profileHeader.handle, profileHeader.emojisJson, (Theme.fontSizeLarge) * sizeMultiplier)
                textFormat: Text.StyledText
                font.pixelSize: (Theme.fontSizeLarge) * sizeMultiplier
                bold: true
                truncationMode: TruncationMode.Fade
            }

            Row {
                //x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                AppLabel {
                    useCustomFont: true
                    text: "@" + profileHeader.handle
                    color: Theme.secondaryColor
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                    truncationMode: TruncationMode.Fade
                    width: parent.width - badgesRow.width - (badgesRow.width > 0 ? parent.spacing : 0)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // No dedicated lock/bot icon in the Silica theme, so use text
                Row {
                    id: badgesRow
                    spacing: Theme.paddingSmall
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        visible: profileHeader.isLocked
                        width: lockedLabel.implicitWidth + Theme.paddingMedium
                        height: lockedLabel.implicitHeight + Theme.paddingSmall
                        radius: height / 2
                        color: Theme.rgba(Theme.primaryColor, 0.1)

                        AppLabel {
                            useCustomFont: true
                            id: lockedLabel
                            anchors.centerIn: parent
                            text: qsTr("Locked")
                            font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                            color: Theme.secondaryColor
                        }
                    }

                    Rectangle {
                        visible: profileHeader.isBot
                        width: botLabel.implicitWidth + Theme.paddingMedium
                        height: botLabel.implicitHeight + Theme.paddingSmall
                        radius: height / 2
                        color: Theme.rgba(Theme.primaryColor, 0.1)

                        AppLabel {
                            useCustomFont: true
                            id: botLabel
                            anchors.centerIn: parent
                            text: qsTr("Bot")
                            font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                            color: Theme.secondaryColor
                        }
                    }
                }
            }
        }
        AppLabel {
            useCustomFont: true
            id: followTextMetrics
            visible: false
            font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
            text: followButton.text
        }

        SecondaryButton {
            id: followButton
            anchors {
                right: parent.right
                rightMargin: Theme.horizontalPageMargin
                verticalCenter: nameColumn.verticalCenter
            }
            preferredWidth: followTextMetrics.implicitWidth + Theme.paddingLarge * 2
            // Hidden entirely when viewing your own profile - you
            // can't follow yourself.
            visible: profileHeader.did.length > 0
                && profileHeader.did !== profileHeader.currentUserDid
            text: profileHeader.viewerFollowing
                ? qsTr("Following") : qsTr("+ Follow")
            color: profileHeader.viewerFollowing
                ? Theme.secondaryColor : palette.secondaryHighlightColor
            onClicked: profileHeader.followClicked()
        }
    }

    //Item { width: 1; height: Theme.paddingMedium }

    Row {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * Theme.horizontalPageMargin
        spacing: Theme.paddingLarge

        Item {
            width: postsColumn.width
            height: postsColumn.height

            Column {
                id: postsColumn
                AppLabel { text: PostMapper.formatCount(profileHeader.postsCount); bold: true; font.pixelSize: (Theme.fontSizeMedium) * sizeMultiplier; useCustomFont: true }
                AppLabel { text: qsTr("Posts"); color: Theme.secondaryColor; font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier; useCustomFont: true }
            }
        }

        Item {
            width: followersColumn.width
            height: followersColumn.height

            Column {
                id: followersColumn
                AppLabel { text: PostMapper.formatCount(profileHeader.followersCount); bold: true; font.pixelSize: (Theme.fontSizeMedium) * sizeMultiplier; useCustomFont: true}
                AppLabel { text: qsTr("Followers"); color: Theme.secondaryColor; font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier; useCustomFont: true }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.paddingSmall
                onClicked: pageStack.push(Qt.resolvedUrl("../FollowListPage.qml"), {
                    did: profileHeader.did,
                    handle: profileHeader.handle,
                    mode: "followers",
                    totalCount: profileHeader.followersCount
                })
            }
        }

        Item {
            width: followsColumn.width
            height: followsColumn.height

            Column {
                id: followsColumn
                AppLabel { text: PostMapper.formatCount(profileHeader.followsCount); bold: true; font.pixelSize: (Theme.fontSizeMedium) * sizeMultiplier; useCustomFont: true }
                AppLabel { text: qsTr("Following"); color: Theme.secondaryColor; font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier; useCustomFont: true }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.paddingSmall
                onClicked: pageStack.push(Qt.resolvedUrl("../FollowListPage.qml"), {
                    did: profileHeader.did,
                    handle: profileHeader.handle,
                    mode: "following",
                    totalCount: profileHeader.followsCount
                })
            }
        }

        Item {
            width: joinedColumn.width
            height: joinedColumn.height
            visible: profileHeader.joinedYear.length > 0

            Column {
                id: joinedColumn
                AppLabel { text: profileHeader.joinedYear; bold: true; font.pixelSize: (Theme.fontSizeMedium) * sizeMultiplier; useCustomFont: true }
                AppLabel { text: qsTr("Joined"); color: Theme.secondaryColor; font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier; useCustomFont: true }
            }
        }
    }

    //Item { width: 1; height: Theme.paddingSmall; visible: profileHeader.familiarFollowers.length > 0 }

    Item {
        id: familiarFollowersItem
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * Theme.horizontalPageMargin
        height: familiarRow.height
        visible: profileHeader.familiarFollowers.length > 0

        Row {
            id: familiarRow
            width: parent.width
            spacing: Theme.paddingMedium

            Row {
                id: familiarAvatarsRow
                spacing: -Theme.paddingLarge
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: Math.min(3, profileHeader.familiarFollowers.length)

                    delegate: Item {
                        width: Theme.iconSizeMedium
                        height: Theme.iconSizeMedium
                        // last on top
                        z: index

                        /*Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: width / 2 // make all round
                            color: Theme.overlayBackgroundColor
                        }*/

                        RoundedAvatar {
                            anchors.centerIn: parent
                            size: parent.width
                            roundRadius: 8 // make squircle
                            source: profileHeader.familiarFollowers[index].avatar || ""
                        }
                    }
                }
            }

            AppLabel {
                useCustomFont: true
                width: parent.width - familiarAvatarsRow.width - parent.spacing
                text: profileHeader.familiarFollowersText
                wrapMode: Text.Wrap
                truncationMode: TruncationMode.Fade
                maximumLineCount: 2
                font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                color: Theme.primaryColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    //Item { width: 1; height: Theme.paddingSmall}

    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * Theme.horizontalPageMargin
        height: bioLabel.implicitHeight
        visible: profileHeader.bio.length > 0

        AppLabel {
            id: bioLabel
            anchors.fill: parent
            // RichText + styleLinks()/styleParagraphs() - same treatment
            // as PostDelegate.qml's post text, and for the same reason:
            // Text.StyledText has no way to suppress a link's default
            // underline, no matter what linkColor is set to (see
            // PostMapper.js's styleLinks() for the full explanation).
            text: PostMapper.styleParagraphs(PostMapper.styleLinks(
                profileHeader.bio, palette.secondaryHighlightColor), Theme.paddingSmall)
            textFormat: Text.RichText
            useCustomFont: true
            wrapMode: Text.Wrap
            font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
            linkColor: palette.secondaryHighlightColor
        }

        MouseArea {
            anchors.fill: bioLabel
            onPressed: mouse.accepted = bioLabel.linkAt(mouse.x, mouse.y).length > 0
            onClicked: {
                var link = bioLabel.linkAt(mouse.x, mouse.y)
                if (link.length > 0)
                    LinkHandler.openLink(link, pageStack, null, null)
            }
        }
    }

    //Item { width: 1; height: Theme.paddingMedium; visible: profileHeader.fieldsList.length > 0 }

    Column {
        id: fieldsColumn
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * Theme.horizontalPageMargin
        visible: profileHeader.fieldsList.length > 0
        spacing: Theme.paddingMedium

        Repeater {
            model: profileHeader.fieldsList

            delegate: Row {
                width: fieldsColumn.width
                spacing: Theme.paddingSmall

                AppLabel {
                    useCustomFont: true
                    text: modelData.name || ""
                    color: Theme.secondaryColor
                    font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                    //bold: true
                    wrapMode: Text.Wrap
                    width: fieldsColumn.width * 0.35
                }

                AppLabel {
                    useCustomFont: true
                    id: fieldValueLabel
                    // Mastodon's own web client highlights a verified
                    // field's value with a green-tinted background rather
                    // than a checkmark icon - no equivalent theme icon
                    // exists here either, so this leans on the same
                    // "highlightColor means verified/active" convention
                    // already used for favourited/reblogged/bookmarked,
                    // plus a plain checkmark glyph (guaranteed to render,
                    // unlike a guessed icon name).
                    // RichText + styleLinks() - same reasoning as bioLabel
                    // above. Field values are single-line, so no
                    // styleParagraphs() needed here.
                    text: (modelData.verified_at ? "✓ " : "")
                        + PostMapper.styleLinks(modelData.value || "", palette.secondaryHighlightColor)
                    textFormat: Text.RichText
                    wrapMode: Text.Wrap
                    font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                    color: modelData.verified_at ? palette.highlightColor : Theme.primaryColor
                    linkColor: palette.secondaryHighlightColor
                    width: fieldsColumn.width * 0.65 - parent.spacing

                    MouseArea {
                        anchors.fill: parent
                        onPressed: mouse.accepted = fieldValueLabel.linkAt(mouse.x, mouse.y).length > 0
                        onClicked: {
                            var link = fieldValueLabel.linkAt(mouse.x, mouse.y)
                            if (link.length > 0)
                                LinkHandler.openLink(link, pageStack, null, null)
                        }
                    }
                }
            }
        }
    }
}
