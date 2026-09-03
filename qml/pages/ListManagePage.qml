import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib" as AppLib
import "../lib/SessionManager.js" as SessionManager
import "../lib/PinnedFeedsStorage.js" as PinnedFeedsStorage
import "../lib/PostMapper.js" as PostMapper
import "../lib/FeedsManager.js" as FeedsManager

// Create/rename/delete your Mastodon Lists, and follow/unfollow hashtags.

AppPage {
    id: listManagePage

    property bool busy: false
    property string errorText: ""

    ListModel {
        id: itemsModel
    }

    // Sets of dismissed list/hashtag ids (from PinnedFeedsStorage)
    property var dismissedIds: ({})
    property var dismissedHashtagIds: ({})

    function refreshDismissedIds() {
        dismissedIds = PinnedFeedsStorage.getDismissedListIds()
        dismissedHashtagIds = PinnedFeedsStorage.getDismissedHashtagIds()
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: itemsModel

        header: PageHeader {
            title: qsTr("Lists & Hashtags")
        }

        section {
            property: "kind"
            delegate: SectionHeader {
                text: section === "hashtag" ? qsTr("Followed hashtags shown in header") : qsTr("Lists shown in header")
            }
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("New list")
                onClicked: listManagePage.promptCreate()
            }
            MenuItem {
                text: qsTr("Follow hashtag")
                onClicked: listManagePage.promptFollowHashtag()
            }
            MenuItem {
                text: qsTr("Refresh")
                onClicked: listManagePage.load()
            }
        }

        delegate: ListItem {
            id: itemDelegate
            contentHeight: Theme.itemSizeMedium

            readonly property bool isList: model.kind === "list"
            readonly property bool shown: isList
                ? (listManagePage.dismissedIds[model.itemId] !== true)
                : (listManagePage.dismissedHashtagIds[model.itemId] !== true)

            onClicked: shownToggle.checked = !shownToggle.checked

            menu: ContextMenu {
                MenuItem {
                    visible: itemDelegate.isList
                    text: qsTr("Edit")
                    onClicked: listManagePage.promptEdit(model.itemId, model.title)
                }
                MenuItem {
                    text: itemDelegate.isList ? qsTr("Delete") : qsTr("Unfollow")
                    onClicked: itemDelegate.remorseAction(
                        itemDelegate.isList ? qsTr("Deleting") : qsTr("Unfollowing"),
                        function() {
                            if (itemDelegate.isList)
                                listManagePage.deleteList(model.itemId, index)
                            else
                                listManagePage.unfollowHashtag(model.itemId, index)
                        }
                    )
                }
            }
            AppLabel {
                width: parent.width - shownToggle.width + 2* Theme.horizontalPageMargin
                anchors.left: parent.left
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                text: model.title
                truncationMode: TruncationMode.Fade
                font.pixelSize: (Theme.fontSizeMedium) * sizeMultiplier
            }

           Switch {
               id: shownToggle
               anchors.right: parent.right
               anchors.rightMargin: Theme.horizontalPageMargin
               anchors.verticalCenter: parent.verticalCenter
               checked: itemDelegate.shown
               onCheckedChanged: {
                   if (checked === itemDelegate.shown)
                       return

                   if (itemDelegate.isList) {
                       if (checked)
                           PinnedFeedsStorage.undismissList(model.itemId)
                       else
                           PinnedFeedsStorage.dismissList(model.itemId)
                   } else {
                       if (checked)
                           PinnedFeedsStorage.undismissHashtag(model.itemId)
                       else
                           PinnedFeedsStorage.dismissHashtag(model.itemId)
                   }

                   listManagePage.refreshDismissedIds()

                   if (checked) {
                       // R ask the server for current data rather
                       FeedsManager.markDirty()
                   } else {
                       // known locally exactly just delete
                       var feedId = itemDelegate.isList
                           ? "list-" + model.itemId : "hashtag-" + model.itemId
                       FeedsManager.removeFeed(feedId)
                   }
               }
           }

        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: !listManagePage.busy && itemsModel.count === 0 && errorText.length === 0
            text: qsTr("Nothing here yet")
            hintText: qsTr("Pull down to create a list or follow a hashtag")
        }

        ViewPlaceholder {
            enabled: errorText.length > 0 && itemsModel.count === 0
            text: qsTr("Couldn't load")
            hintText: errorText
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: listManagePage.busy && itemsModel.count === 0
        visible: running
        size: BusyIndicatorSize.Large
    }

    Component.onCompleted: load()

    function load() {
        if (busy)
            return

        busy = true
        errorText = ""
        refreshDismissedIds()

        var listsResult = null
        var tagsResult = null
        var pending = 2
        var sessionExpired = false

        function handleFailure(status, message) {
            if (status === 401 && !sessionExpired) {
                sessionExpired = true
                SessionManager.clearSession()
                pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
                return
            }
            pending -= 1
            checkDone()
        }

        function checkDone() {
            if (pending > 0)
                return

            busy = false

            if (sessionExpired)
                return

            itemsModel.clear()
            ;(listsResult || []).forEach(function(l) {
                itemsModel.append({ kind: "list", itemId: l.id, title: l.title })
            })
            ;(tagsResult || []).forEach(function(t) {
                itemsModel.append({ kind: "hashtag", itemId: t.name, title: "#" + t.name })
            })
        }

        SessionManager.authenticatedRequest("GET", "/api/v1/lists", null,
            function(response) {
                listsResult = response || []
                pending -= 1
                checkDone()
            },
            function(status, message) {
                if (status !== 401)
                    errorText = qsTr("Couldn't load lists (%1)").arg(message || status)
                listsResult = []
                handleFailure(status, message)
            }
        )

        SessionManager.authenticatedRequest("GET", "/api/v1/followed_tags?limit=40", null,
            function(response) {
                tagsResult = response || []
                pending -= 1
                checkDone()
            },
            function(status, message) {
                if (status !== 401)
                    console.warn("[ListManage] loading followed hashtags failed:", status, message)
                tagsResult = []
                handleFailure(status, message)
            }
        )
    }

    function promptCreate() {
        var dialog = pageStack.push(nameDialogComponent, {
            dialogTitle: qsTr("New list"),
            initialText: ""
        })
        dialog.accepted.connect(function() {
            listManagePage.createList(dialog.nameText)
        })
    }

    function promptEdit(listId, currentTitle) {
        var dialog = pageStack.push(nameDialogComponent, {
            dialogTitle: qsTr("Edit list"),
            initialText: currentTitle,
            listId: listId
        })
        dialog.accepted.connect(function() {
            listManagePage.renameList(listId, dialog.nameText)
        })
    }

    function promptFollowHashtag() {
        var dialog = pageStack.push(nameDialogComponent, {
            dialogTitle: qsTr("Follow hashtag"),
            initialText: ""
        })
        dialog.accepted.connect(function() {
            listManagePage.followHashtag(dialog.nameText)
        })
    }

    function createList(title) {
        if (!title || title.length === 0)
            return

        SessionManager.authenticatedRequest("POST", "/api/v1/lists", { title: title },
            function(response) {
                // markDirty() first - the carousel refresh must not be
                // blocked by listManagePage.load() below throwing if this
                // page has already been popped/torn down by the time this
                // response lands (e.g. navigated away right after acting,
                // without waiting around on this page). load() itself is
                // then best-effort for the same reason - nothing left to
                // refresh if the page is already gone.
                FeedsManager.markDirty()
                try { listManagePage.load() } catch (e) {}
            },
            function(status, message) {
                console.warn("[ListManage] create failed:", status, message)
                try { errorText = qsTr("Couldn't create list (%1)").arg(message || status) } catch (e) {}
            }
        )
    }

    function renameList(listId, title) {
        if (!title || title.length === 0)
            return

        SessionManager.authenticatedRequest("PUT", "/api/v1/lists/" + encodeURIComponent(listId), { title: title },
            function(response) {
                FeedsManager.markDirty()
                try { listManagePage.load() } catch (e) {}
            },
            function(status, message) {
                console.warn("[ListManage] rename failed:", status, message)
                try { errorText = qsTr("Couldn't rename list (%1)").arg(message || status) } catch (e) {}
            }
        )
    }

    function deleteList(listId, rowIndex) {
        itemsModel.remove(rowIndex)

        SessionManager.authenticatedRequest("DELETE", "/api/v1/lists/" + encodeURIComponent(listId), null,
            function(response) {
                // Already known locally exactly which feed just stopped
                // belonging - no server round-trip needed to remove it from
                // the carousel, unlike markDirty()'s full loadFeeds() resync.
                FeedsManager.removeFeed("list-" + listId)
                // Tidy up a leftover dismissed-id entry - a plain storage
                // write, safe regardless of whether this page still exists.
                PinnedFeedsStorage.undismissList(listId)
                // refreshDismissedIds() only updates this page's own
                // displayed state - best-effort, since a slow response can
                // land well after the user has swiped away and moved on to
                // other feeds, by which point there's nothing left to
                // refresh here.
                try { refreshDismissedIds() } catch (e) {}
            },
            function(status, message) {
                console.warn("[ListManage] delete failed:", status, message)
                // Same best-effort reasoning as the success path above -
                // this page may already be gone by the time a failure comes
                // back too.
                try {
                    errorText = qsTr("Couldn't delete list (%1)").arg(message || status)
                    listManagePage.load() // restore the row since the delete didn't actually happen
                } catch (e) {}
            }
        )
    }

    function followHashtag(name) {
        var normalized = (name || "").replace(/^#/, "").trim()
        if (normalized.length === 0)
            return

        SessionManager.authenticatedRequest("POST",
            "/api/v1/tags/" + encodeURIComponent(normalized) + "/follow", {},
            function(response) {
                FeedsManager.markDirty()
                try { listManagePage.load() } catch (e) {}
            },
            function(status, message) {
                console.warn("[ListManage] follow hashtag failed:", status, message)
                try { errorText = qsTr("Couldn't follow #%1 (%2)").arg(normalized).arg(message || status) } catch (e) {}
            }
        )
    }

    function unfollowHashtag(name, rowIndex) {
        itemsModel.remove(rowIndex)

        SessionManager.authenticatedRequest("POST",
            "/api/v1/tags/" + encodeURIComponent(name) + "/unfollow", {},
            function(response) {
                FeedsManager.removeFeed("hashtag-" + name)
            },
            function(status, message) {
                console.warn("[ListManage] unfollow hashtag failed:", status, message)
                try {
                    errorText = qsTr("Couldn't unfollow #%1 (%2)").arg(name).arg(message || status)
                    listManagePage.load() // restore the row since the unfollow didn't actually happen
                } catch (e) {}
            }
        )
    }

    Component {
        id: nameDialogComponent

        Dialog {
            id: nameDialog

            // needs these as dialog is not AppPage
            backgroundColor: AppLib.BackgroundManager.backgroundColor
            palette.highlightColor: AppLib.BackgroundManager.activeHighlightColor
            palette.highlightBackgroundColor: AppLib.BackgroundManager.activeHighlightBackgroundColor

            property string dialogTitle: ""
            property string initialText: ""
            property alias nameText: nameField.text

            // Non-empty only for promptEdit() (an existing list)
            property string listId: ""
            property bool membersLoading: false

            canAccept: nameField.text.trim().length > 0

            onAccepted: nameText = nameField.text.trim()

            Component.onCompleted: {
                if (listId.length > 0)
                    loadMembers()
            }

            ListModel {
                id: membersModel
            }

            function loadMembers() {
                membersLoading = true
                SessionManager.authenticatedRequest("GET",
                    "/api/v1/lists/" + encodeURIComponent(listId) + "/accounts?limit=40", null,
                    function(response) {
                        membersLoading = false
                        membersModel.clear()
                        ;(response || []).forEach(function(a) {
                            membersModel.append({
                                accountId: a.id,
                                handle: a.acct,
                                displayName: a.display_name || "",
                                emojisJson: PostMapper.emojiMapJson(a.emojis),
                                avatarUrl: a.avatar || ""
                            })
                        })
                    },
                    function(status, message) {
                        membersLoading = false
                        console.warn("[ListManage] loading list members failed:", status, message)
                    }
                )
            }

            // Removed immediately on tap btw
            function removeMember(accountId, rowIndex) {
                membersModel.remove(rowIndex)

                SessionManager.authenticatedRequest("DELETE",
                    "/api/v1/lists/" + encodeURIComponent(listId) + "/accounts",
                    { account_ids: [accountId] },
                    function(response) {},
                    function(status, message) {
                        console.warn("[ListManage] removing list member failed:", status, message)
                        loadMembers() // restore since it didn't actually happen
                    }
                )
            }

            SilicaFlickable {
                anchors.fill: parent
                contentHeight: membersColumn.y + membersColumn.height + Theme.paddingLarge

                DialogHeader {
                    id: dialogTitleText
                    title: nameDialog.dialogTitle
                }

                TextField {
                    id: nameField
                    anchors.top: dialogTitleText.bottom
                    anchors.topMargin: Theme.paddingMedium
                    width: parent.width
                    label: qsTr("Name")
                    text: nameDialog.initialText
                    EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                    EnterKey.onClicked: nameDialog.accept()
                }

                SectionHeader {
                    id: membersHeader
                    anchors.top: nameField.bottom
                    visible: nameDialog.listId.length > 0
                    text: qsTr("Members")
                }

                BusyIndicator {
                    anchors {
                        top: membersHeader.bottom
                        topMargin: Theme.paddingMedium
                        horizontalCenter: parent.horizontalCenter
                    }
                    running: nameDialog.listId.length > 0 && nameDialog.membersLoading
                    visible: running
                    size: BusyIndicatorSize.Medium
                }

                Column {
                    id: membersColumn
                    anchors.top: membersHeader.bottom
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    visible: nameDialog.listId.length > 0 && !nameDialog.membersLoading

                    AppLabel {
                        width: parent.width
                        visible: nameDialog.listId.length > 0 && membersRepeater.count === 0
                        text: qsTr("No members yet")
                        color: Theme.secondaryColor
                        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                    }

                    Repeater {
                        id: membersRepeater
                        model: membersModel

                        Item {
                            width: membersColumn.width
                            height: memberRow.height + Theme.paddingMedium

                            Row {
                                id: memberRow
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                spacing: Theme.paddingMedium

                                RoundedAvatar {
                                    size: Theme.iconSizeMedium
                                    source: model.avatarUrl
                                }

                                Column {
                                    width: parent.width - Theme.iconSizeMedium - removeButton.width - parent.spacing * 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.paddingSmall / 2

                                    AppLabel {
                                        width: parent.width
                                        text: AppLib.EmojiManager.render(model.displayName || model.handle, model.emojisJson, (Theme.fontSizeExtraSmall) * sizeMultiplier)
                                        textFormat: Text.StyledText
                                        bold: true
                                        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                                        truncationMode: TruncationMode.Fade
                                    }

                                    AppLabel {
                                        width: parent.width
                                        text: "@" + model.handle
                                        color: Theme.secondaryColor
                                        font.pixelSize: (Theme.fontSizeExtraSmall) * sizeMultiplier
                                        truncationMode: TruncationMode.Fade
                                    }
                                }

                                SecondaryButton {
                                    id: removeButton
                                    preferredWidth: Theme.buttonWidthExtraSmall
                                    text: qsTr("Remove")
                                    onClicked: nameDialog.removeMember(model.accountId, index)
                                }
                            }
                        }
                    }
                }

                VerticalScrollDecorator {}
            }
        }
    }
}
