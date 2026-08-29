import QtQuick 2.0
import Sailfish.Silica 1.0
import "components"
import "../lib/SessionManager.js" as SessionManager
import "../lib/VideoExpansionTracker.js" as VideoExpansionTracker
import "../lib" as AppLib

AppPage {
    id: mainPage
    //backgroundColor: Theme.rgba(Theme.darkSecondaryColor, 0.8)

    backNavigation: false

    // Only allow forward-swipe on the tab that actually has a picker
    forwardNavigation: currentTab === 3

    property int currentTab: 0 // 0=Timeline 1=Search 2=Notifications 3=Profile

    // Glonbal hide-on-scroll-down/show-on-scroll-up tab bar (DockedPanel below),
    // plus forcing it hidden whenever a video is expanded full-width
    property bool anyVideoExpanded: false

    readonly property bool activeTabHidden: {
        switch (currentTab) {
        case 0: return feedCarouselViewInstance.tabBarHidden
        case 1: return searchViewInstance.tabBarHidden
        case 2: return notificationsViewInstance.tabBarHidden
        case 3: return profileViewInstance.tabBarHidden
        }
        return false
    }

    readonly property bool tabBarShouldShow: !anyVideoExpanded && !activeTabHidden

    // self-heal because can happen
    onTabBarShouldShowChanged: {
        if (tabBarShouldShow)
            tabBar.show()
        else
            tabBar.hide()
    }

    // becaue MainPage owns all picker attach/detach directly ..
    property bool pickerOpen: false
    property string pendingPicker: "" // "profile" | ""

    function requestProfilePicker() {
        pendingPicker = "profile"
        pickerStepTimer.restart()
    }

    // Used after a selection is made - close whatever's attached only
    function closePickerOnly() {
        pendingPicker = ""
        pickerStepTimer.restart()
    }

    // Trying to avoid a pageStack operation while one is already in progress
    // Actially should clean this up, and get rid of picker pages...
    Timer {
        id: pickerStepTimer
        interval: 30
        running: false
        repeat: true
        onTriggered: {
            if (pageStack.busy)
                return // something's still animating - check again next tick
            if (pickerOpen) {
                pickerOpen = false
                pageStack.pop(pageStack.previousPage())
                return
            }

            running = false

            if (pendingPicker === "profile") {
                var profilePicker = pageStack.pushAttached(Qt.resolvedUrl("ProfileSectionPickerPage.qml"), {
                    currentSection: profileViewInstance.currentSection
                })
                pickerOpen = true
                profilePicker.sectionSelected.connect(function(section) {
                    if (section === "lists") {
                        pageStack.navigateBack()
                        pageStack.push(Qt.resolvedUrl("ListManagePage.qml"))
                    } else {
                        profileViewInstance.switchSection(section)
                        pageStack.navigateBack()
                    }
                })
            }

            pendingPicker = ""
        }
    }

    // On every tab switch: always tear down whatever's attached
    onCurrentTabChanged: {
        if (currentTab === 3)
            requestProfilePicker()
        else
            closePickerOnly()
    }


    Component.onCompleted: {
        if (!SessionManager.isLoggedIn())
            redirectToLoginTimer.start()

        VideoExpansionTracker.subscribe(function(expanded) {
            mainPage.anyVideoExpanded = expanded
        })
        // Explicit initial call
        if (tabBarShouldShow)
            tabBar.show()
        else
            tabBar.hide()
    }

    Timer {
        id: redirectToLoginTimer
        interval: 0
        running: false
        repeat: false
        onTriggered: pageStack.animatorReplace(Qt.resolvedUrl("FirstPage.qml"))
    }

    Item {
        id: contentArea
        clip: true
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: tabBar.visibleSize
        }

        // All four views are instantiated once and kept alive - makes it snappier

        FeedCarouselView {
            id: feedCarouselViewInstance
            anchors.fill: parent
            visible: mainPage.currentTab === 0
            isPortrait: mainPage.isPortrait
        }

        SearchView {
            id: searchViewInstance
            anchors.fill: parent
            visible: mainPage.currentTab === 1
        }

        NotificationsView {
            id: notificationsViewInstance
            anchors.fill: parent
            visible: mainPage.currentTab === 2
        }

        ProfileView {
            id: profileViewInstance
            anchors.fill: parent
            visible: mainPage.currentTab === 3
            onRequestPicker: mainPage.requestProfilePicker()
        }
    }

    DockedPanel {
        id: tabBar
        width: parent.width
        height: Theme.itemSizeMedium

        background: PanelBackground {
            anchors.fill: parent
            opacity: AppLib.BackgroundManager.affectTabBar
                ? 1 - AppLib.BackgroundManager.opacity : 1
        }
        NoiseOverlay {
            anchors.fill: parent
            //visible: AppLib.BackgroundManager.affectCover
            strength: 0.04
        }
        dock: Dock.Bottom
        open: true // real control via show()/hide()

        Row {
            anchors.fill: parent
            TabBarButton {
                width: parent.width / 5
                height: parent.height
                iconSource: "image://theme/icon-m-home"
                selected: mainPage.currentTab === 0
                onClicked: {
                    if (mainPage.currentTab === 0) {
                        feedCarouselViewInstance.scrollToTop()
                        tabBar.show()
                    } else {
                        mainPage.currentTab = 0
                    }
                }
            }

            TabBarButton {
                width: parent.width / 5
                height: parent.height
                iconSource: "image://theme/icon-m-search"
                selected: mainPage.currentTab === 1
                onClicked: {
                    if (mainPage.currentTab === 1) {
                        searchViewInstance.scrollToTop()
                        tabBar.show()
                    } else {
                        mainPage.currentTab = 1
                    }
                }
            }

            // New-post action, not a tab
            TabBarButton {
                width: parent.width / 5
                height: parent.height
                iconSource: "image://theme/icon-l-add" //"image://theme/icon-m-edit-selected"
                decorated: false
                onClicked: pageStack.push(Qt.resolvedUrl("ComposePage.qml"))
            }

            TabBarButton {
                width: parent.width / 5
                height: parent.height
                iconSource: "image://theme/icon-m-alarm"
                selected: mainPage.currentTab === 2
                onClicked: {
                    if (mainPage.currentTab === 2) {
                        notificationsViewInstance.scrollToTop()
                        tabBar.show()
                    } else {
                        mainPage.currentTab = 2
                    }
                }
            }

            TabBarButton {
                width: parent.width / 5
                height: parent.height
                iconSource: "image://theme/icon-m-people"
                selected: mainPage.currentTab === 3
                onClicked: {
                    if (mainPage.currentTab === 3) {
                        profileViewInstance.scrollToTop()
                        tabBar.show()
                    } else {
                        mainPage.currentTab = 3
                    }
                }
            }
        }
    }
}
