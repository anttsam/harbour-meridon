import QtQuick 2.0
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import harbour.meridon.Native 1.0
import "components"
import "../lib" as AppLib
import "../lib/SessionManager.js" as SessionManager
import "../lib/PostEvents.js" as PostEvents

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

    // Poll: a post can carry media OR a poll, never both. Limits are the
    // Mastodon defaults until the instance says otherwise (loadCharLimit()).
    property bool pollEnabled: false
    property int pollMaxOptions: 4
    property int pollMaxChars: 50
    property int pollMinExpiration: 300
    property int pollMaxExpiration: 2629746
    property int pollExpiresIn: 86400
    property bool pollMultiple: false
    // Bumped whenever an option's text changes - ListModel.get(i).prop isn't
    // bindable, so the validity bindings below hang on this.
    property int pollRevision: 0
    ListModel {
        id: pollModel
    }

    // Lengths the duration picker offers, within the instance's limits
    readonly property var pollDurations: {
        var all = [300, 1800, 3600, 21600, 86400, 259200, 604800]
        var out = []
        for (var i = 0; i < all.length; i++) {
            if (all[i] >= pollMinExpiration && all[i] <= pollMaxExpiration)
                out.push(all[i])
        }
        return out
    }
    readonly property bool pollHasDuplicates: {
        pollRevision
        return pollHasDuplicateOptions()
    }
    readonly property bool pollValid: {
        pollRevision
        return pollOptionList().length >= 2 && !pollHasDuplicates
    }

    // Mastodon can't edit a post's poll without resetting its votes, so
    // editing posts that have one is blocked
    property bool editBlockedByPoll: false

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

    function pollOptionList() {
        var out = []
        for (var i = 0; i < pollModel.count; i++) {
            var t = pollModel.get(i).optionText.trim()
            if (t.length > 0)
                out.push(t)
        }
        return out
    }

    function pollHasDuplicateOptions() {
        var seen = {}
        var list = pollOptionList()
        for (var i = 0; i < list.length; i++) {
            if (seen["k" + list[i]])
                return true
            seen["k" + list[i]] = true
        }
        return false
    }

    function pollDurationLabel(seconds) {
        switch (seconds) {
        case 300: return qsTr("5 minutes")
        case 1800: return qsTr("30 minutes")
        case 3600: return qsTr("1 hour")
        case 21600: return qsTr("6 hours")
        case 86400: return qsTr("1 day")
        case 259200: return qsTr("3 days")
        case 604800: return qsTr("7 days")
        }
        return ""
    }

    // Keeps the chosen length inside what the instance allows
    function clampPollDuration() {
        var list = pollDurations
        if (list.length === 0 || list.indexOf(pollExpiresIn) >= 0)
            return
        var best = list[0]
        for (var i = 0; i < list.length; i++) {
            if (Math.abs(list[i] - 86400) < Math.abs(best - 86400))
                best = list[i]
        }
        pollExpiresIn = best
    }

    function togglePoll() {
        if (pollEnabled) {
            // hiding keeps whatever is typed, like the content warning
            pollEnabled = false
            return
        }
        while (pollModel.count < 2)
            pollModel.append({ optionText: "" })
        pollEnabled = true
        pollOptionsRepeater.itemAt(0).focusField()
    }

    function pollAddOption() {
        if (pollModel.count >= pollMaxOptions)
            return
        pollModel.append({ optionText: "" })
        pollRevision++
        pollOptionsRepeater.itemAt(pollModel.count - 1).focusField()
    }

    // Enter in an option: on to the next one, adding one after the last
    function pollNext(index) {
        if (index < pollModel.count - 1)
            pollOptionsRepeater.itemAt(index + 1).focusField()
        else if (pollModel.count < pollMaxOptions)
            pollAddOption()
        else
            Qt.inputMethod.hide()
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

                var pollConfig = response.configuration && response.configuration.polls
                if (pollConfig) {
                    if (pollConfig.max_options)
                        pollMaxOptions = pollConfig.max_options
                    if (pollConfig.max_characters_per_option)
                        pollMaxChars = pollConfig.max_characters_per_option
                    if (pollConfig.min_expiration)
                        pollMinExpiration = pollConfig.min_expiration
                    if (pollConfig.max_expiration)
                        pollMaxExpiration = pollConfig.max_expiration
                    clampPollDuration()
                }
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

                if (response.poll) {
                    composePage.editBlockedByPoll = true
                    composePage.errorText = qsTr("Posts with a poll can't be edited")
                }

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
            bottom: bottomPanel.top
        }
        clip: true

        contentHeight: composeRow.height + cwField.height + privacySelector.height + Theme.paddingLarge

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
                                sourceSize.width: attachmentItem.width
                                sourceSize.height: attachmentItem.height
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

                Column {
                    id: pollBlock
                    width: parent.width
                    visible: composePage.pollEnabled
                    enabled: visible

                    // Rows are laid out by hand rather than in a Column so one
                    // can follow the finger while the rest slide out of its
                    // way; the model is only reordered when the drag ends.
                    Item {
                        id: pollOptions
                        width: parent.width
                        height: pollModel.count * rowHeight

                        readonly property real rowHeight: Theme.itemSizeMedium
                        property int dragIndex: -1
                        property int dropIndex: -1
                        property real dragY: 0

                        function finishDrag() {
                            var from = dragIndex
                            var to = dropIndex
                            dragIndex = -1
                            dropIndex = -1
                            if (from >= 0 && to >= 0 && from !== to) {
                                pollModel.move(from, to, 1)
                                composePage.pollRevision++
                            }
                        }

                        Repeater {
                            id: pollOptionsRepeater
                            model: pollModel

                            Item {
                                id: optionRow
                                width: pollOptions.width
                                height: pollOptions.rowHeight

                                readonly property bool dragging: pollOptions.dragIndex === index
                                readonly property int slot: {
                                    if (pollOptions.dragIndex < 0 || dragging)
                                        return index
                                    if (index > pollOptions.dragIndex && index <= pollOptions.dropIndex)
                                        return index - 1
                                    if (index < pollOptions.dragIndex && index >= pollOptions.dropIndex)
                                        return index + 1
                                    return index
                                }

                                y: dragging ? pollOptions.dragY : slot * pollOptions.rowHeight
                                z: dragging ? 2 : 1
                                Behavior on y {
                                    enabled: !optionRow.dragging
                                    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                                }

                                function focusField() {
                                    optionField.forceActiveFocus()
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    visible: optionRow.dragging
                                    radius: Theme.paddingSmall
                                    color: Theme.rgba(palette.highlightBackgroundColor, 0.25)
                                }

                                TextField {
                                    id: optionField
                                    anchors {
                                        left: parent.left
                                        right: removeButton.left
                                        verticalCenter: parent.verticalCenter
                                    }
                                    labelVisible: false
                                    placeholderText: qsTr("Choice %1").arg(index + 1)
                                    EnterKey.iconSource: "image://theme/icon-m-enter-next"
                                    EnterKey.onClicked: composePage.pollNext(index)

                                    // Assigned, not bound: trimming below would break a binding anyway
                                    Component.onCompleted: text = model.optionText
                                    onTextChanged: {
                                        if (text.length > composePage.pollMaxChars) {
                                            text = text.substring(0, composePage.pollMaxChars)
                                            return
                                        }
                                        if (index < pollModel.count && pollModel.get(index).optionText !== text) {
                                            pollModel.setProperty(index, "optionText", text)
                                            composePage.pollRevision++
                                        }
                                    }
                                }

                                IconButton {
                                    id: removeButton
                                    anchors {
                                        right: dragHandle.left
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width: Theme.itemSizeExtraSmall
                                    height: parent.height
                                    icon.source: "image://theme/icon-m-dismiss"
                                    opacity: pollModel.count > 2 ? 1.0 : 0.0
                                    enabled: pollModel.count > 2
                                    onClicked: {
                                        pollModel.remove(index)
                                        composePage.pollRevision++
                                    }
                                }

                                // Hold and drag to move the choice up or down
                                MouseArea {
                                    id: dragHandle
                                    anchors {
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width: Theme.itemSizeExtraSmall
                                    height: parent.height
                                    preventStealing: true
                                    visible: pollModel.count > 1

                                    Icon {
                                        anchors.centerIn: parent
                                        source: "image://theme/icon-m-menu"
                                        opacity: dragHandle.pressed ? 1.0 : Theme.opacityHigh
                                    }

                                    onPressed: {
                                        Qt.inputMethod.hide()
                                        pollOptions.dragIndex = index
                                        pollOptions.dropIndex = index
                                        pollOptions.dragY = optionRow.y
                                    }
                                    onPositionChanged: {
                                        if (pollOptions.dragIndex !== index)
                                            return
                                        var p = mapToItem(pollOptions, mouse.x, mouse.y)
                                        var last = pollModel.count - 1
                                        pollOptions.dragY = Math.max(0, Math.min(
                                            p.y - pollOptions.rowHeight / 2, last * pollOptions.rowHeight))
                                        pollOptions.dropIndex = Math.max(0, Math.min(
                                            last, Math.floor(p.y / pollOptions.rowHeight)))
                                    }
                                    onReleased: pollOptions.finishDrag()
                                    onCanceled: pollOptions.finishDrag()
                                }
                            }
                        }
                    }

                    BackgroundItem {
                        width: parent.width
                        height: Theme.itemSizeSmall
                        visible: pollModel.count < composePage.pollMaxOptions
                        onClicked: composePage.pollAddOption()

                        Icon {
                            id: addChoiceIcon
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://theme/icon-m-add"
                            color: parent.highlighted ? palette.highlightColor : palette.primaryColor
                        }
                        AppLabel {
                            anchors {
                                left: addChoiceIcon.right
                                leftMargin: Theme.paddingMedium
                                verticalCenter: parent.verticalCenter
                            }
                            text: qsTr("Add choice")
                            color: parent.highlighted ? palette.highlightColor : palette.primaryColor
                        }
                    }

                    AppLabel {
                        width: parent.width
                        visible: composePage.pollHasDuplicates
                        text: qsTr("Choices must be different")
                        color: Theme.highlightColor
                        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                    }

                    ComboBox {
                        width: parent.width
                        label: qsTr("Duration")
                        currentIndex: composePage.pollDurations.indexOf(composePage.pollExpiresIn)
                        menu: ContextMenu {
                            Repeater {
                                model: composePage.pollDurations
                                MenuItem { text: composePage.pollDurationLabel(modelData) }
                            }
                        }
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0)
                                composePage.pollExpiresIn = composePage.pollDurations[currentIndex]
                        }
                    }

                    TextSwitch {
                        width: parent.width
                        text: qsTr("Allow multiple choices")
                        checked: composePage.pollMultiple
                        onCheckedChanged: composePage.pollMultiple = checked
                    }
                }
            }
        }
    }

    // A plain anchored Item, not a DockedPanel - matching harbour-sailsky's
    // ComposePage (footerRow), which has no overlap/cursor-visibility issues
    // at all. A DockedPanel re-parents itself onto a non-resizing window-
    // level item and positions itself via animated x/y rather than normal
    // anchors, which both fights with flick's own anchors.bottom: bottomPanel.top
    // above and confuses PageStack's own height tracking. Since this toolbar
    // has its own real space here (flick's viewport genuinely ends above
    // it, no floating overlay to work around), Silica's built-in
    // cursor-follows-keyboard behavior for postField just works correctly
    // on its own - no bottomMargin or manual scroll nudging needed.
    Item {
        id: bottomPanel
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: actionsRow.height + toolsRow.height

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
                    && (!composePage.pollEnabled || composePage.pollValid)
                    && !composePage.editBlockedByPoll
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
                enabled: attachmentsModel.count < composePage.maxAttachments && !composePage.pollEnabled
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
                enabled: attachmentsModel.count < composePage.maxAttachments && !composePage.pollEnabled
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
                enabled: attachmentsModel.count < composePage.maxAttachments && !composePage.pollEnabled
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
                        var picker = pageStack.push(Qt.resolvedUrl("components/EmojiPickerPage.qml"))
                        picker.emojiInserted.connect(function(text) {
                            composePage.insertAtCursor(text)
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

            // No poll icon in the theme: three bars of different lengths
            Item {
                id: pollButton
                anchors {
                    left: cwButton.right
                    verticalCenter: parent.verticalCenter
                }
                width: Theme.itemSizeMedium
                height: Theme.itemSizeMedium
                enabled: !composePage.isEditing && attachmentsModel.count === 0
                opacity: enabled ? 1.0 : Theme.opacityLow

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.paddingSmall
                    opacity: pollMouseArea.pressed ? 0.5 : 1.0

                    Repeater {
                        model: [0.9, 0.55, 0.75]
                        Rectangle {
                            width: Theme.iconSizeMedium * modelData
                            height: Theme.paddingSmall
                            radius: height / 2
                            color: composePage.pollEnabled ? palette.highlightColor : palette.primaryColor
                        }
                    }
                }

                MouseArea {
                    id: pollMouseArea
                    anchors.fill: parent
                    onClicked: composePage.togglePoll()
                }
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
        if (editBlockedByPoll || (pollEnabled && !pollValid))
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
            if (pollEnabled) {
                body.poll = {
                    options: pollOptionList(),
                    expires_in: pollExpiresIn,
                    multiple: pollMultiple
                }
            }
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
                PostEvents.posted()
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
