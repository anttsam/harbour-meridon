import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import "lib/FeedsManager.js" as FeedsManager
import "lib/UrlRouter.js" as UrlRouter
import "lib/PeerTube.js" as PeerTube

ApplicationWindow {
    id: applicationWindow
    initialPage: Component { MainPage { } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    // Called from main.cpp (UrlRouter::urlReceived) when the OS hands https:// link
    function handleIncomingUrl(url) {
        console.log("[UrlRouter] handleIncomingUrl:", url)
        var video = PeerTube.parseVideoUrl(url)
        if (video) {
            PeerTube.fetchVideo(video.host, video.id, function (json) {
                pageStack.push(Qt.resolvedUrl("pages/PeerTubePage.qml"),
                               { host: video.host, videoId: video.id, pageUrl: url, video: json })
            }, function () {
                routeIncomingUrl(url)
            })
            return
        }
        routeIncomingUrl(url)
    }

    function routeIncomingUrl(url) {
        UrlRouter.resolveAndRoute(url,
            function (statusId) {
                console.log("[UrlRouter] -> PostDetailPage", statusId)
                pageStack.push(Qt.resolvedUrl("pages/PostDetailPage.qml"), { postUri: statusId })
            },
            function (accountId) {
                console.log("[UrlRouter] -> UserProfilePage", accountId)
                pageStack.push(Qt.resolvedUrl("pages/UserProfilePage.qml"), { did: accountId })
            },
            function (tag) {
                console.log("[UrlRouter] -> HashtagPage", tag)
                pageStack.push(Qt.resolvedUrl("pages/HashtagPage.qml"), { hashtag: tag })
            },
            function () {
                console.log("[UrlRouter] -> unhandled, opening externally")
                Qt.openUrlExternally(url) //Falls back tfor anything can't place nativel
            })
    }

    WorkerScript {
        id: feedMapperWorker
        source: Qt.resolvedUrl("lib/FeedMapperWorker.js")
        onMessage: FeedsManager.handleWorkerMessage(messageObject)
    }

    Component.onCompleted: FeedsManager.setWorker(feedMapperWorker)
}
