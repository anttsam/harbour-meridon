import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib" as AppLib
import "../lib/Lemmy.js" as Lemmy
import "../lib/Markdown.js" as Markdown
import "../lib/PostMapper.js" as PostMapper
import "../lib/LinkHandler.js" as LinkHandler

// A Lemmy post with its comments, read only. Mastodon only carries the title
// and a link for these (see Lemmy.js), so everything comes from the server
// the link pointed at. Kept apart from PostDetailPage, which is built around
// Mastodon's /context.

AppPage {
    id: lemmyPage

    property string host: ""
    property string postId: ""
    // The link the user followed, for the browser fallback
    property string pageUrl: ""
    // Callers that already fetched the post (to check it is one) pass it in
    property var postView: null

    property string errorText: ""
    property bool busy: false

    property string sortMode: "Hot" // Hot | Top | New | Old
    property bool commentsLoading: false
    property string commentsError: ""
    // Drops responses from before a refresh or a change of sort order
    property int generation: 0

    readonly property var post: postView ? postView.post : null
    readonly property bool isImage: post !== null && !!post.url && /^image\//i.test(post.url_content_type || "")
    readonly property bool hasLink: post !== null && !!post.url && !isImage
    readonly property string browserUrl: pageUrl.length > 0
        ? pageUrl : "https://" + host + "/post/" + postId

    // The whole thread in tree order. The model only holds what is
    // expanded: top level comments to begin with, so a long thread starts short.
    property var allRows: []

    ListModel {
        id: commentModel
    }

    function openInBrowser() {
        pageStack.push(Qt.resolvedUrl("WebViewPage.qml"), { url: browserUrl })
    }

    function load() {
        generation++
        errorText = ""
        if (postView) {
            loadComments()
            return
        }
        busy = true
        var current = generation
        Lemmy.fetchPost(host, postId, function (view) {
            if (current !== generation)
                return
            busy = false
            postView = view
            loadComments()
        }, function (status, message) {
            if (current !== generation)
                return
            busy = false
            errorText = message
        })
    }

    function loadComments() {
        generation++
        var current = generation
        commentModel.clear()
        commentsError = ""
        commentsLoading = true
        Lemmy.fetchComments(host, post.id, sortMode, function (views) {
            if (current !== generation)
                return
            allRows = Lemmy.buildRows(views, Markdown.toHtml, host)
            for (var i = 0; i < allRows.length; i++)
                if (allRows[i].depth === 0)
                    commentModel.append(allRows[i])
            commentsLoading = false
        }, function (status, message) {
            if (current !== generation)
                return
            commentsError = message
            commentsLoading = false
        })
    }

    // Shows the direct replies of the comment at index, each collapsed
    function expandReplies(index) {
        var row = commentModel.get(index)
        var at = -1
        for (var i = 0; i < allRows.length; i++) {
            if (allRows[i].commentId === row.commentId) {
                at = i
                break
            }
        }
        if (at < 0)
            return
        var inserted = 0
        for (var j = at + 1; j < allRows.length && allRows[j].depth > row.depth; j++) {
            if (allRows[j].depth === row.depth + 1) {
                commentModel.insert(index + 1 + inserted, allRows[j])
                inserted++
            }
        }
        commentModel.setProperty(index, "repliesLoaded", true)
    }

    // Removes everything shown below the comment at index
    function collapseReplies(index) {
        var depth = commentModel.get(index).depth
        while (index + 1 < commentModel.count && commentModel.get(index + 1).depth > depth)
            commentModel.remove(index + 1)
        commentModel.setProperty(index, "repliesLoaded", false)
    }

    function applySort(mode) {
        if (sortMode === mode)
            return
        sortMode = mode
        loadComments()
    }

    Component.onCompleted: load()

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: commentModel
        cacheBuffer: 2000

        PullDownMenu {
            MenuItem {
                text: qsTr("Open in browser")
                onClicked: lemmyPage.openInBrowser()
            }
            MenuItem {
                text: qsTr("Comments: Hot")
                visible: lemmyPage.sortMode !== "Hot"
                onClicked: lemmyPage.applySort("Hot")
            }
            MenuItem {
                text: qsTr("Comments: Top")
                visible: lemmyPage.sortMode !== "Top"
                onClicked: lemmyPage.applySort("Top")
            }
            MenuItem {
                text: qsTr("Comments: Newest first")
                visible: lemmyPage.sortMode !== "New"
                onClicked: lemmyPage.applySort("New")
            }
            MenuItem {
                text: qsTr("Comments: Oldest first")
                visible: lemmyPage.sortMode !== "Old"
                onClicked: lemmyPage.applySort("Old")
            }
        }

        header: Column {
            width: listView.width

            PageHeader {
                title: lemmyPage.postView ? (lemmyPage.postView.community.title || lemmyPage.postView.community.name) : "Lemmy"
                description: lemmyPage.postView
                    ? lemmyPage.postView.community.name + "@" + lemmyPage.host : lemmyPage.host
            }

            Column {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium
                visible: lemmyPage.post !== null

                AppLabel {
                    width: parent.width
                    text: lemmyPage.post ? lemmyPage.post.name : ""
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeMedium * sizeMultiplier
                    bold: true
                    color: Theme.primaryColor
                    useCustomFont: true
                }

                AppLabel {
                    width: parent.width
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                    color: Theme.secondaryColor
                    text: {
                        if (!lemmyPage.postView)
                            return ""
                        AppLib.TimeManager.tick
                        var parts = [Lemmy.handleOf(lemmyPage.postView.creator)]
                        parts.push(PostMapper.formatTimeAgo(lemmyPage.post.published))
                        parts.push(qsTr("%n point(s)", "", lemmyPage.postView.counts.score))
                        parts.push(qsTr("%n comment(s)", "", lemmyPage.postView.counts.comments))
                        if (lemmyPage.post.nsfw)
                            parts.push("NSFW")
                        return parts.join("  ·  ")
                    }
                }

                // An image post
                Image {
                    id: postImage
                    width: parent.width
                    height: status === Image.Ready ? implicitHeight : 0
                    visible: lemmyPage.isImage
                    source: lemmyPage.isImage ? lemmyPage.post.url : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.width: width

                    MouseArea {
                        anchors.fill: parent
                        onClicked: LinkHandler.openLink(lemmyPage.post.url, pageStack, {}, {})
                    }
                }

                // A link post: thumbnail, the site's title and its domain
                Rectangle {
                    width: parent.width
                    height: linkColumn.height + Theme.paddingMedium
                    visible: lemmyPage.hasLink
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.primaryColor, 0.06)
                    border.color: Theme.rgba(Theme.primaryColor, 0.15)
                    border.width: 1
                    clip: true

                    Column {
                        id: linkColumn
                        width: parent.width
                        spacing: Theme.paddingSmall

                        Image {
                            width: parent.width
                            height: visible ? width * 0.5 : 0
                            visible: lemmyPage.hasLink && !!lemmyPage.post.thumbnail_url
                            source: visible ? lemmyPage.post.thumbnail_url : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: width
                        }

                        AppLabel {
                            x: Theme.paddingMedium
                            width: parent.width - 2 * Theme.paddingMedium
                            visible: text.length > 0
                            text: lemmyPage.hasLink ? (lemmyPage.post.embed_title || "") : ""
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            truncationMode: TruncationMode.Fade
                            font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                            bold: true
                            color: Theme.primaryColor
                            useCustomFont: true
                        }

                        AppLabel {
                            x: Theme.paddingMedium
                            width: parent.width - 2 * Theme.paddingMedium
                            text: lemmyPage.hasLink ? PostMapper.extractDomain(lemmyPage.post.url) : ""
                            truncationMode: TruncationMode.Fade
                            font.pixelSize: Theme.fontSizeExtraSmall * sizeMultiplier
                            color: Theme.secondaryColor
                        }

                        Item { width: 1; height: Theme.paddingSmall / 2 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: LinkHandler.openLink(lemmyPage.post.url, pageStack, {}, {})
                    }
                }

                Item {
                    width: parent.width
                    height: bodyLabel.implicitHeight
                    visible: bodyLabel.text.length > 0

                    AppLabel {
                        id: bodyLabel
                        anchors.fill: parent
                        text: lemmyPage.post && lemmyPage.post.body && !lemmyPage.post.removed && !lemmyPage.post.deleted
                            ? PostMapper.styleParagraphs(PostMapper.styleLinks(
                                  Markdown.toHtml(lemmyPage.post.body, lemmyPage.host),
                                  palette.secondaryHighlightColor), Theme.paddingSmall) : ""
                        textFormat: Text.RichText
                        useCustomFont: true
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall * sizeMultiplier
                        color: Theme.primaryColor
                        linkColor: palette.secondaryHighlightColor
                    }

                    MouseArea {
                        anchors.fill: bodyLabel
                        onPressed: mouse.accepted = bodyLabel.linkAt(mouse.x, mouse.y).length > 0
                        onClicked: {
                            var link = bodyLabel.linkAt(mouse.x, mouse.y)
                            if (link.length > 0)
                                LinkHandler.openLink(link, pageStack, {}, {})
                        }
                    }
                }

                AppLabel {
                    width: parent.width
                    visible: lemmyPage.post !== null && (lemmyPage.post.removed || lemmyPage.post.deleted)
                    text: qsTr("This post was removed")
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall * sizeMultiplier
                    font.italic: true
                    color: Theme.secondaryColor
                }
            }

            SectionHeader {
                text: qsTr("Comments")
                visible: lemmyPage.post !== null
            }

            AppLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: lemmyPage.post !== null && !lemmyPage.commentsLoading
                    && lemmyPage.commentsError.length === 0 && commentModel.count === 0
                text: qsTr("No comments yet")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall * sizeMultiplier
            }
        }

        delegate: ThreadComment {
            depth: model.depth
            html: model.html
            isDeleted: model.isDeleted
            authorName: model.authorName
            authorHandle: model.authorHandle
            avatarUrl: model.avatarUrl
            createdAt: model.createdAt
            showScore: true
            score: model.score
            totalReplies: model.totalReplies
            repliesLoaded: model.repliesLoaded
            canHide: true
            onShowReplies: lemmyPage.expandReplies(index)
            onHideReplies: lemmyPage.collapseReplies(index)
            onLinkClicked: LinkHandler.openLink(link, pageStack, {}, {})
        }

        footer: Item {
            width: listView.width
            height: lemmyPage.commentsLoading || lemmyPage.commentsError.length > 0
                ? Theme.itemSizeLarge : Theme.paddingLarge

            BusyIndicator {
                anchors.centerIn: parent
                running: lemmyPage.commentsLoading
                visible: running
                size: BusyIndicatorSize.Medium
            }

            Button {
                anchors.centerIn: parent
                visible: lemmyPage.commentsError.length > 0 && !lemmyPage.commentsLoading
                text: qsTr("Retry")
                onClicked: lemmyPage.loadComments()
            }
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: lemmyPage.errorText.length > 0
            text: qsTr("Couldn't load post")
            hintText: lemmyPage.errorText

            Button {
                anchors {
                    top: parent.bottom
                    topMargin: Theme.paddingLarge
                    horizontalCenter: parent.horizontalCenter
                }
                text: qsTr("Open in browser")
                onClicked: lemmyPage.openInBrowser()
            }
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: lemmyPage.busy
        visible: running
        size: BusyIndicatorSize.Large
    }
}
