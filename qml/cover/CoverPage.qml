/*
  Copyright (C) 2013 Jolla Ltd.
  Contact: Thomas Perl <thomas.perl@jollamobile.com>
  All rights reserved.

  You may use this file under the terms of BSD license as follows:

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Jolla Ltd nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import QtQuick 2.0
import Sailfish.Silica 1.0
import "../lib/FeedsManager.js" as FeedsManager
import "../lib" as AppLib
import "../pages/components"

CoverBackground {
    id: cover

    property bool refreshing: false
    property var homeContent: FeedsManager.peekFeedContent("home")
    readonly property var homeModel: homeContent ? homeContent.model : null
    readonly property int previewCount: homeModel ? Math.min(homeModel.count, 3) : 0

    palette.highlightColor: AppLib.BackgroundManager.activeHighlightColor
    palette.highlightBackgroundColor: AppLib.BackgroundManager.activeHighlightBackgroundColor

    Rectangle {
        anchors.fill: parent
        visible: AppLib.BackgroundManager.affectCover
        color: AppLib.BackgroundManager.backgroundColor
    }
    Rectangle {
        id: coverHue
        height: parent.height
        width: parent.width
        anchors.centerIn: parent
        gradient: Gradient {
            //GradientStop { position: 0.0; color: Theme.rgba(Theme.primaryColor, 0.1) }
            //GradientStop { position: 1.0; color: Theme.rgba(Theme.highlightColor, 0.2) }
            GradientStop { position: 0.0; color: palette.highlightColor }
            GradientStop { position: 1.0; color: "transparent" }

        }
        opacity: 0.3
        visible: AppLib.BackgroundManager.affectCover

    }
    NoiseOverlay {
        anchors.fill: parent
        visible: AppLib.BackgroundManager.affectCover
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cover.homeContent = FeedsManager.peekFeedContent("home")
    }

    /*Image {
        id: appIcon
        anchors {
            top: parent.top
            topMargin: Theme.paddingMedium
            horizontalCenter: parent.horizontalCenter
        }
        source: "../../icons/86x86/harbour-meridon.png"
        width: Theme.iconSizeSmall
        height: width
        smooth: true
    }*/
    Row {
        id: appIcon
        anchors {
            top: parent.top
            topMargin: Theme.paddingMedium
            horizontalCenter: parent.horizontalCenter
        }
        height: appName.height
        spacing: Theme.paddingSmall
        Image {
            width: appName.height * 0.8
            height: width
            source: Qt.resolvedUrl("../images/harbour-meridon.png")
            smooth: true
            asynchronous: true
            opacity: 0.5
            anchors.top: appName.top

        }
        Label {
            id: appName
            text: "Meridon"
            color: Theme.secondaryColor

        }
    }



    Column {
        id: postsColumn
        anchors {
            top: appIcon.bottom
            topMargin: Theme.paddingMedium
            left: parent.left
            right: parent.right
            leftMargin: Theme.paddingMedium
            rightMargin: Theme.paddingMedium
        }
        spacing: Theme.paddingMedium
        visible: cover.previewCount > 0
        opacity: cover.refreshing ? 0.5 : 1

        NumberAnimation {
            target: postsColumn
            property: "opacity"
            duration: 300
            easing.type: Easing.InOutQuad
        }

        Repeater {
            model: cover.previewCount

            Row {
                width: postsColumn.width
                spacing: Theme.paddingSmall

                // Guards against homeModel swapping out mid-refresh (e.g. on relogin)
                property var post: (cover.homeModel && index < cover.homeModel.count)
                    ? cover.homeModel.get(index) : null

                Rectangle {
                    width: Theme.iconSizeExtraSmall
                    height: width
                    radius: width / 8 // squircle
                    color: Theme.rgba(Theme.primaryColor, 0.15)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: post ? post.avatarUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Column {
                    width: parent.width - Theme.iconSizeExtraSmall - parent.spacing
                    spacing: 2

                    Label {
                        width: parent.width
                        text: post ? AppLib.EmojiManager.render(post.displayName || post.handle, post.authorEmojisJson, Theme.fontSizeTiny) : ""
                        textFormat: Text.StyledText
                        font.pixelSize: Theme.fontSizeTiny
                        font.bold: true
                        color: Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                        maximumLineCount: 1
                    }

                    Label {
                        width: parent.width
                        text: post ? AppLib.EmojiManager.render(post.postText, post.postEmojisJson, Theme.fontSizeTiny) : ""
                        textFormat: Text.StyledText
                        linkColor: palette.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeTiny
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        truncationMode: TruncationMode.Fade
                    }
                }
            }
        }
    }

    // placeholder
    Label {
        anchors.centerIn: parent
        visible: !postsColumn.visible
        text: "Meridon"
        color: Theme.secondaryColor
        font.pixelSize: Theme.fontSizeLarge
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: cover.refreshing
        visible: running
        size: BusyIndicatorSize.Large
        //does anyone know how to make this running in background without forcing?
        _forceAnimation: running
    }

    CoverActionList {
        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            onTriggered: {
                pageStack.push(Qt.resolvedUrl("../pages/ComposePage.qml"))
                applicationWindow.activate()
            }
        }

        CoverAction {
            iconSource: "image://theme/icon-cover-sync"
            onTriggered: {
                if (FeedsManager.peekFeedContent("home") && !cover.refreshing) {
                    cover.refreshing = true
                    FeedsManager.loadFeedContent(FeedsManager.defaultHomeFeed(), true, null, function() {
                        cover.refreshing = false
                    })
                }
            }
        }
    }
}
