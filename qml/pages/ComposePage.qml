import QtQuick 2.0
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import harbour.meridon.Native 1.0
import "components"
import "../lib" as AppLib
import "../lib/SessionManager.js" as SessionManager

FullscreenContentPage {
    id: composePage

    navigationStyle: PageNavigation.Vertical

    // FullscreenContentPage.qml hardcodes colors, so can't do this
    //backgroundColor: AppLib.BackgroundManager.backgroundColor

    palette.highlightColor: AppLib.BackgroundManager.activeHighlightColor
    palette.highlightBackgroundColor: AppLib.BackgroundManager.activeHighlightBackgroundColor
    NoiseOverlay {
        anchors.fill: parent
        //visible: AppLib.BackgroundManager.affectCover
        strength: 0.04
    }

    property bool posting: false
    property string errorText: ""
    property string myAvatarUrl: ""

    // when editingUri is non-empty, this page acts as an editor
    property string editingUri: ""
    readonly property bool isEditing: editingUri.length > 0

    // when replyToUri is non-empty, this page acts as a reply composer
    property string replyToUri: ""
    property string replyToAuthorName: ""
    property string replyToAuthorEmojisJson: "{}"
    property string replyToAuthorAvatar: ""
    property string replyToText: ""

    // when quotedStatusUri is non-empty, this new post quotes it (Mastodon's
    // POST /api/v1/statuses "quoted_status_id" - never sent when editing,
    // there's no way to attach a quote to an already-published post)
    property string quotedStatusUri: ""
    property string quotedAuthorName: ""
    property string quotedAuthorHandle: ""
    property string quotedAuthorAvatar: ""
    property string quotedText: ""

    // 500 is Mastodon's common default
    property int charLimit: 500
    readonly property int charsLeft: charLimit - postField.text.length
        - (cwEnabled ? cwFieldText.text.length : 0)

    property bool cwEnabled: false

    // 4 is Mastodon's own common default
    property int maxAttachments: 4
    property int uploadingCount: 0
    property int nextAttachmentKey: 0
    ListModel {
        id: attachmentsModel
    }

    // Mastodon's own POST /api/v1/statuses "visibility" values
    readonly property var visibilityOptions: ["public", "unlisted", "private", "direct"]
    property string visibility: "public"

    Component.onCompleted: {
        loadOwnAvatar()
        loadCharLimit()
        if (composePage.isEditing)
            loadEditSource()
    }

    Component {
        id: imagePickerPageComponent
        ImagePickerPage {
            onSelectedContentPropertiesChanged: {
                composePage.addAttachment(selectedContentProperties.filePath, "image")
            }
        }
    }

    Component {
        id: videoPickerPageComponent
        VideoPickerPage {
            onSelectedContentPropertiesChanged: {
                composePage.addAttachment(selectedContentProperties.filePath, "video")
            }
        }
    }

    Component {
        id: audioPickerPageComponent
        MusicPickerPage {
            onSelectedContentPropertiesChanged: {
                composePage.addAttachment(selectedContentProperties.filePath, "audio")
            }
        }
    }

    MediaUploader {
        id: mediaUploader
        onUploadSucceeded: composePage.onUploadFinished(parseInt(requestId, 10), mediaId, "")
        onUploadFailed: composePage.onUploadFinished(parseInt(requestId, 10), "", message || String(status))
    }

    function startUpload(key, filePath) {
        var session = SessionManager.getSession()
        mediaUploader.upload(String(key), session.instanceUrl, session.accessToken, filePath)
    }

    // Uploads immeadetely
    function addAttachment(filePath, kind) {
        if (attachmentsModel.count >= composePage.maxAttachments)
            return

        var key = composePage.nextAttachmentKey++
        attachmentsModel.append({ key: key, filePath: filePath, kind: kind, mediaId: "", uploading: true, failed: false, remote: false })
        composePage.uploadingCount += 1
        startUpload(key, filePath)
    }

    // Re-uses the failed row's own key
    function retryAttachment(key) {
        var i = attachmentIndexForKey(key)
        if (i < 0)
            return

        attachmentsModel.setProperty(i, "uploading", true)
        attachmentsModel.setProperty(i, "failed", false)
        composePage.uploadingCount += 1
        startUpload(key, attachmentsModel.get(i).filePath)
    }

    function attachmentIndexForKey(key) {
        for (var i = 0; i < attachmentsModel.count; i++) {
            if (attachmentsModel.get(i).key === key)
                return i
        }
        return -1
    }

    function onUploadFinished(key, mediaId, error) {
        composePage.uploadingCount = Math.max(0, composePage.uploadingCount - 1)

        var i = attachmentIndexForKey(key)
        if (i < 0)
            return // removed while still uploading

        if (mediaId.length > 0) {
            attachmentsModel.setProperty(i, "mediaId", mediaId)
            attachmentsModel.setProperty(i, "uploading", false)
        } else {
            attachmentsModel.setProperty(i, "uploading", false)
            attachmentsModel.setProperty(i, "failed", true)
            composePage.errorText = qsTr("Couldn't upload attachment (%1)").arg(error)
        }
    }

    function removeAttachment(key) {
        var i = attachmentIndexForKey(key)
        if (i >= 0)
            attachmentsModel.remove(i)
    }

    function collectMediaIds() {
        var ids = []
        for (var i = 0; i < attachmentsModel.count; i++) {
            var mediaId = attachmentsModel.get(i).mediaId
            if (mediaId.length > 0)
                ids.push(mediaId)
        }
        return ids
    }

    // TextArea.insert() not available in older Qt
    function insertAtCursor(text) {
        var pos = postField.cursorPosition
        var before = postField.text.substring(0, pos)
        var after = postField.text.substring(pos)
        postField.text = before + text + after
        postField.cursorPosition = pos + text.length
    }

    function loadOwnAvatar() {
        var session = SessionManager.getSession()
        if (!session)
            return

        SessionManager.authenticatedRequest("GET", "/api/v1/accounts/verify_credentials", null,
            function(response) {
                myAvatarUrl = response.avatar || ""
                // Seeds the visibility picker from the account
                if (response.source && response.source.privacy)
                    composePage.visibility = response.source.privacy
            },
            function(status, message) {
                console.warn("[Compose] couldn't load own avatar:", status, message)
            }
        )
    }

    function loadCharLimit() {
        SessionManager.authenticatedRequest("GET", "/api/v1/instance", null,
            function(response) {
                // older Mastodon servers limit more, try both
                var statusesConfig = response.configuration && response.configuration.statuses
                var limit = (statusesConfig && statusesConfig.max_characters) || response.max_toot_chars
                if (limit)
                    charLimit = limit
                var mediaLimit = statusesConfig && statusesConfig.max_media_attachments
                if (mediaLimit)
                    maxAttachments = mediaLimit
            },
            function(status, message) {
                console.warn("[Compose] couldn't load instance char limit, using default:", status, message)
            }
        )
    }

    // Mastodon exposes the original raw text (and warning) specifically for edit flows
    function loadEditSource() {
        SessionManager.authenticatedRequest("GET",
            "/api/v1/statuses/" + encodeURIComponent(editingUri) + "/source", null,
            function(response) {
                postField.text = response.text || ""
                if (response.spoiler_text && response.spoiler_text.length > 0) {
                    cwFieldText.text = response.spoiler_text
                    cwEnabled = true
                }
            },
            function(status, message) {
                console.warn("[Compose] couldn't load post source to edit:", status, message)
                errorText = qsTr("Couldn't load post to edit")
            }
        )

        SessionManager.authenticatedRequest("GET",
            "/api/v1/statuses/" + encodeURIComponent(editingUri), null,
            function(response) {
                if (response.visibility)
                    composePage.visibility = response.visibility

                var attachments = response.media_attachments || []
                for (var i = 0; i < attachments.length; i++) {
                    var att = attachments[i]
                    attachmentsModel.append({
                        key: composePage.nextAttachmentKey++,
                        filePath: att.preview_url || att.url,
                        kind: (att.type === "video" || att.type === "gifv") ? "video"
                            : (att.type === "audio" ? "audio" : "image"),
                        mediaId: att.id,
                        uploading: false,
                        failed: false,
                        remote: true
                    })
                }
            },
            function(status, message) {
                console.warn("[Compose] couldn't load post details to edit:", status, message)
            }
        )
    }

    PageHeader {
        id:headerRow
        title: composePage.isEditing ? qsTr("Edit post")
            : (composePage.replyToUri.length > 0 ? qsTr("Reply")
            : (composePage.quotedStatusUri.length > 0 ? qsTr("Quote") : qsTr("New post")))
    }

    Item {
        id: replyPreview
        width: parent.width
        height: composePage.replyToUri.length > 0
            ? replyPreviewRow.height + Theme.paddingMedium * 2 : 0
        anchors.top: headerRow.bottom
        clip: true

        Row {
            id: replyPreviewRow
            x: Theme.horizontalPageMargin
            y: Theme.paddingMedium
            width: parent.width - 2 * Theme.horizontalPageMargin
            spacing: Theme.paddingMedium

            RoundedAvatar {
                size: Theme.iconSizeMedium
                source: composePage.replyToAuthorAvatar
            }

            Column {
                width: parent.width - Theme.iconSizeMedium - parent.spacing
                spacing: Theme.paddingSmall

                AppLabel {
                    width: parent.width
                    text: AppLib.EmojiManager.render(composePage.replyToAuthorName, composePage.replyToAuthorEmojisJson, (Theme.fontSizeSmall) * sizeMultiplier)
                    textFormat: Text.StyledText
                    bold: true
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                    truncationMode: TruncationMode.Fade
                    color: palette.primaryColor
                }

                AppLabel {
                    width: parent.width
                    text: composePage.replyToText
                    wrapMode: Text.Wrap
                    maximumLineCount: 5
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: (Theme.fontSizeSmall) * sizeMultiplier
                    color: palette.secondaryColor
                    linkColor: palette.secondaryHighlightColor
                }
            }
        }
    }

    Item {
        id: quotePreview
        width: parent.width
        anchors.top: replyPreview.bottom
        height: composePage.quotedStatusUri.length > 0
            ? quotePreviewCard.height + Theme.paddingMedium * 2 : 0
        clip: true

        PostQuoteCard {
            id: quotePreviewCard
            x: Theme.horizontalPageMargin
            y: Theme.paddingMedium
            width: parent.width - 2 * Theme.horizontalPageMargin
            quote: composePage.quotedStatusUri.length > 0 ? {
                uri: composePage.quotedStatusUri,
                authorName: composePage.quotedAuthorName,
                authorHandle: composePage.quotedAuthorHandle,
                authorAvatar: composePage.quotedAuthorAvatar,
                text: composePage.quotedText,
                thumbUrl: "",
                unavailable: false
            } : null
        }
    }

    SilicaFlickable {
        id: flick
        anchors {
            top: quotePreview.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        contentHeight: composeRow.height + cwField.height + privacySelector.height + Theme.paddingLarge
        bottomMargin: bottomPanel.height

        ComboBox {
            id: privacySelector
            // Mastodon's edit endpoint can't change a post's visibility
            enabled: !composePage.isEditing
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                rightMargin: Theme.horizontalPageMargin
            }
            label: "Visibility: "
            currentIndex: composePage.visibilityOptions.indexOf(composePage.visibility)
            menu: ContextMenu {
                MenuItem { text: qsTr("Public") }
                MenuItem { text: qsTr("Quiet public") }
                MenuItem { text: qsTr("Followers only") }
                MenuItem { text: qsTr("Only people I mention") }
            }
            onCurrentIndexChanged: {
                if (currentIndex >= 0)
                    composePage.visibility = composePage.visibilityOptions[currentIndex]
            }
        }

        Row {
            id: cwField
            anchors {
                top: privacySelector.bottom
                topMargin: Theme.paddingLarge
                left: parent.left
                right: parent.right
                leftMargin: Theme.horizontalPageMargin
                rightMargin: Theme.horizontalPageMargin
            }
            Icon {
                source:  "image://theme/icon-m-warning"
                width: Theme.iconSizeMedium
                anchors.verticalCenter: cwField.verticalCenter

            }
            TextArea {
                id: cwFieldText
                /*background: PanelBackground {
                    anchors.fill: parent
                    opacity: 0.2
                }*/
                width: cwField.width - Theme.iconSizeMedium //- 2* Theme.horizontalPageMargin

                //backgroundStyle: TextEditor.FilledBackground
                label: qsTr("Warning")

                placeholderText: qsTr("Write an accurate warning here")
                placeholderColor: palette.highlightColor
                font.pixelSize: Theme.fontSizeMedium
                color: palette.highlightColor
                clip: true

            }

            // hiding shouldn't lose whatever is typed already
            height: composePage.cwEnabled ? implicitHeight : 0
            opacity: composePage.cwEnabled ? 1.0 : 0.0
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

            visible: height > 0
            enabled: visible
        }



        Row {
            id: composeRow
            x: Theme.horizontalPageMargin
            anchors.top: cwField.bottom
            anchors.topMargin: Theme.paddingLarge
            width: parent.width - 2 * Theme.horizontalPageMargin
            //spacing: Theme.paddingMedium

            RoundedAvatar {
                size: Theme.iconSizeMedium
                source: composePage.myAvatarUrl
            }

            Column {
                width: parent.width - Theme.iconSizeMedium - parent.spacing
                spacing: Theme.paddingMedium

                TextArea {
                    id: postField
                    width: parent.width
                    placeholderText: composePage.replyToUri.length > 0 ? qsTr("Write your reply")
                        : (composePage.quotedStatusUri.length > 0 ? qsTr("Add a comment") : qsTr("What's up?"))
                    font.pixelSize: Theme.fontSizeMedium
                    focus: true
                }

                Flow {
                    id: attachmentsFlow
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: attachmentsModel.count > 0

                    Repeater {
                        model: attachmentsModel

                        Rectangle {
                            id: attachmentItem
                            width: (attachmentsFlow.width - Theme.paddingSmall) / 2
                            height: width * 0.66
                            radius: Theme.paddingSmall
                            color: Theme.rgba(Theme.primaryColor, 0.08)
                            clip: true

                            // needs the file:// scheme
                            readonly property string displaySource: model.remote
                                ? model.filePath : ("file://" + model.filePath)

                            Image {
                                anchors.fill: parent
                                visible: model.kind === "image"
                                source: model.kind === "image" ? attachmentItem.displaySource : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            // Video/audio have no still frame , just show some icon instead
                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.paddingSmall
                                visible: model.kind !== "image"

                                Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    source: model.kind === "video" ? "image://theme/icon-m-video" : "image://theme/icon-m-music"
                                }

                                AppLabel {
                                    width: attachmentItem.width - 2 * Theme.paddingSmall
                                    horizontalAlignment: Text.AlignHCenter
                                    truncationMode: TruncationMode.Fade
                                    font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                                    color: Theme.secondaryColor
                                    text: model.filePath.substring(model.filePath.lastIndexOf("/") + 1)
                                }
                            }

                            BusyIndicator {
                                anchors.centerIn: parent
                                size: BusyIndicatorSize.Small
                                running: model.uploading
                                visible: running
                            }

                            Icon {
                                anchors.centerIn: parent
                                source: "image://theme/icon-m-warning"
                                visible: model.failed
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (model.failed) {
                                        composePage.retryAttachment(model.key)
                                    } else if (model.kind === "image") {
                                        pageStack.push(Qt.resolvedUrl("ImageViewerPage.qml"), {
                                            images: [{
                                                thumbUrl: attachmentItem.displaySource,
                                                fullsizeUrl: attachmentItem.displaySource,
                                                alt: ""
                                            }],
                                            startIndex: 0
                                        })
                                    } else if (model.kind === "video") {
                                        pageStack.push(Qt.resolvedUrl("VideoPlayerPage.qml"), {
                                            playlistUrl: attachmentItem.displaySource
                                        })
                                    }
                                    // audio playback/ preview is not implemented
                                }
                            }

                            IconButton {
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                }
                                width: Theme.iconSizeMedium
                                height: width
                                icon.source: "image://theme/icon-m-dismiss"
                                onClicked: composePage.removeAttachment(model.key)
                            }
                        }
                    }
                }
            }
        }
    }

    DockedPanel {
        id: bottomPanel
        width: parent.width
        height: actionsRow.height + toolsRow.height
        dock: Dock.Bottom
        open: true

        NoiseOverlay {
            anchors.fill: parent
            //visible: AppLib.BackgroundManager.affectCover
            strength: 0.04
        }

        Item {
            id: actionsRow
            anchors.top: parent.top
            width: parent.width
            height: Theme.itemSizeMedium

            SecondaryButton {
                preferredWidth: Theme.buttonWidthSmall
                icon.source: "image://theme/icon-splus-clear"
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                text: qsTr("Cancel")
                onClicked: pageStack.pop()
            }

            Button {
                id: postLabel
                preferredWidth: Theme.buttonWidthSmall
                icon.source: "image://theme/icon-m-send"
                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                layoutDirection: Qt.RightToLeft
                text: composePage.posting
                    ? (composePage.isEditing ? qsTr("Saving...") : qsTr("Posting..."))
                    : (composePage.isEditing ? qsTr("Save") : qsTr("Post"))
                color: canPost ? palette.highlightColor : Theme.secondaryColor

                readonly property bool canPost: (postField.text.trim().length > 0 || attachmentsModel.count > 0)
                    && charsLeft >= 0 && !composePage.posting && composePage.uploadingCount === 0
                onClicked: composePage.submitPost()
            }
        }

        Item {
            id: toolsRow
            anchors.top: actionsRow.bottom
            width: parent.width
            height: Theme.itemSizeMedium

            IconButton {
                id: imageButton
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                width: Theme.itemSizeMedium
                icon.source: "image://theme/icon-m-image"
                enabled: attachmentsModel.count < composePage.maxAttachments
                onClicked: pageStack.push(imagePickerPageComponent)
            }

            IconButton {
                id: videoButton
                anchors {
                    left: imageButton.right
                    verticalCenter: parent.verticalCenter
                }
                width: Theme.itemSizeMedium
                icon.source: "image://theme/icon-m-video"
                enabled: attachmentsModel.count < composePage.maxAttachments
                onClicked: pageStack.push(videoPickerPageComponent)
            }

            IconButton {
                id: audioButton
                anchors {
                    left: videoButton.right
                    verticalCenter: parent.verticalCenter
                }
                width: Theme.itemSizeMedium
                icon.source: "image://theme/icon-m-music"
                enabled: attachmentsModel.count < composePage.maxAttachments
                onClicked: pageStack.push(audioPickerPageComponent)
            }

            Item {
                id: emojiButton
                anchors {
                    left: audioButton.right
                    verticalCenter: parent.verticalCenter
                }
                width: Theme.itemSizeMedium
                height: Theme.itemSizeMedium

                Image {
                    id: smileyImage
                    anchors.centerIn: parent
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    source: "../images/smiley.png"
                    visible: false
                }

                ColorOverlay {
                    anchors.fill: smileyImage
                    source: smileyImage
                    color: composePage.palette.primaryColor
                    opacity: emojiMouseArea.pressed ? 0.5 : 1.0
                }

                MouseArea {
                    id: emojiMouseArea
                    anchors.fill: parent
                    onClicked: {
                        var dialog = pageStack.push(Qt.resolvedUrl("components/EmojiPickerDialog.qml"))
                        dialog.accepted.connect(function() {
                            composePage.insertAtCursor(dialog.insertText)
                        })
                    }
                }
            }

            IconButton {
                id: cwButton
                anchors {
                    left: emojiButton.right
                    verticalCenter: parent.verticalCenter
                }
                width: Theme.itemSizeMedium
                icon.source: "image://theme/icon-m-warning"
                icon.color: composePage.cwEnabled ? palette.highlightColor : palette.primaryColor
                onClicked: composePage.cwEnabled = !composePage.cwEnabled
            }

            AppLabel {
                id: charCountLabel
                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                text: composePage.charsLeft
                font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                color: composePage.charsLeft < 0 ? Theme.highlightColor : Theme.secondaryColor
            }


        }
    }

    AppLabel {
        anchors {
            bottom: bottomPanel.top
            bottomMargin: Theme.paddingSmall
            horizontalCenter: parent.horizontalCenter
        }
        visible: errorText.length > 0
        text: errorText
        color: Theme.highlightColor
        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier

        Timer {
            interval: 3000
            running: errorText.length > 0
            onTriggered: errorText = ""
        }
    }



    function submitPost() {
        if (posting)
            return

        var text = postField.text.trim()
        var mediaIds = collectMediaIds()
        if ((text.length === 0 && mediaIds.length === 0) || charsLeft < 0)
            return

        posting = true
        errorText = ""

        var body = { status: text }

        if (composePage.isEditing) {
            // need to explicitely send these or old values presist
            body.media_ids = mediaIds
            body.spoiler_text = (composePage.cwEnabled && cwFieldText.text.trim().length > 0)
                ? cwFieldText.text.trim() : ""
        } else {
            body.visibility = composePage.visibility
            if (replyToUri.length > 0)
                body.in_reply_to_id = replyToUri
            if (quotedStatusUri.length > 0)
                body.quoted_status_id = quotedStatusUri
            if (mediaIds.length > 0)
                body.media_ids = mediaIds
            // Only sent with actual warning text.
            if (composePage.cwEnabled && cwFieldText.text.trim().length > 0)
                body.spoiler_text = cwFieldText.text.trim()
        }

        var method = composePage.isEditing ? "PUT" : "POST"
        var path = composePage.isEditing
            ? "/api/v1/statuses/" + encodeURIComponent(composePage.editingUri)
            : "/api/v1/statuses"

        SessionManager.authenticatedRequest(method, path, body,
            function(response) {
                posting = false
                pageStack.pop()
            },
            function(status, message) {
                posting = false
                errorText = composePage.isEditing
                    ? qsTr("Couldn't save (%1)").arg(message || status)
                    : qsTr("Couldn't post (%1)").arg(message || status)
            }
        )
    }
}
