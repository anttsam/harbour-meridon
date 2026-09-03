# NOTICE:
#
# Application name defined in TARGET has a corresponding QML filename.
# If name defined in TARGET is changed, the following needs to be done
# to match new name:
#   - corresponding QML filename must be changed
#   - desktop icon filename must be changed
#   - desktop filename must be changed
#   - icon definition filename in desktop file must be changed
#   - translation filenames have to be changed

# The name of your application
TARGET = harbour-meridon

CONFIG += sailfishapp
#CONFIG += link_pkgconfig
#PKGCONFIG += qt5embedwidget

QT += network dbus

SOURCES += src/harbour-meridon.cpp \
    src/mediauploader.cpp \
    src/urlrouter.cpp

HEADERS += src/mediauploader.h \
    src/urlrouter.h

# desktop entry claiming x-scheme-handler/https - see src/urlrouter.h
openurl_desktop.files = harbour-meridon-open-url.desktop
openurl_desktop.path = /usr/share/applications
INSTALLS += openurl_desktop

DISTFILES += qml/harbour-meridon.qml \
    qml/pages/AboutPage.qml \
    qml/images/harbour-meridon.png \
    qml/cover/CoverPage.qml \
    qml/pages/ComposePage.qml \
    qml/pages/FirstPage.qml \
    qml/pages/FollowListPage.qml \
    qml/pages/HashtagPage.qml \
    qml/pages/ImageViewerPage.qml \
    qml/pages/ListManagePage.qml \
    qml/pages/ListPickerPage.qml \
    qml/pages/MainPage.qml \
    qml/pages/OAuthLoginPage.qml \
    qml/pages/PostDetailPage.qml \
    qml/pages/SettingsPage.qml \
    qml/pages/UserProfilePage.qml \
    qml/pages/VideoPlayerPage.qml \
    qml/pages/WebViewPage.qml \
    qml/pages/components/AppLabel.qml \
    qml/pages/components/AppPage.qml \
    qml/pages/components/EmojiPickerDialog.qml \
    qml/pages/components/NoiseOverlay.qml \
    qml/pages/components/noise.png \
    qml/pages/components/FeedCarouselView.qml \
    qml/pages/components/FeedPane.qml \
    qml/pages/components/FeedTabStrip.qml \
    qml/pages/components/MoreSlide.qml \
    qml/pages/components/NotificationsView.qml \
    qml/pages/components/PostDelegate.qml \
    qml/pages/components/PostImageGrid.qml \
    qml/pages/components/PostLinkCard.qml \
    qml/pages/components/PostPoll.qml \
    qml/pages/components/PostContentWarning.qml \
    qml/pages/components/PostQuoteCard.qml \
    qml/pages/components/PostStatsRow.qml \
    qml/pages/components/PostVideo.qml \
    qml/pages/components/ProfileHeader.qml \
    qml/pages/components/ProfileView.qml \
    qml/pages/components/RoundedAvatar.qml \
    qml/pages/components/ScrollDirectionTracker.qml \
    qml/pages/components/SearchView.qml \
    qml/pages/components/TabBarButton.qml \
    qml/lib/FeedsManager.js \
    qml/lib/FeedMapperWorker.js \
    qml/lib/BackgroundManager.qml \
    qml/lib/EmojiManager.qml \
    qml/lib/EmojiCodepoints.js \
    qml/lib/EmojiRecentStorage.js \
    qml/lib/emoji/*.png \
    qml/lib/flags/*.png \
    qml/lib/FontManager.qml \
    qml/lib/FontPreferenceStorage.js \
    qml/lib/HttpClient.js \
    qml/lib/InstanceAppStorage.js \
    qml/lib/LinkHandler.js \
    qml/lib/LocalDb.js \
    qml/lib/PinnedFeedsStorage.js \
    qml/lib/PostMapper.js \
    qml/lib/PresetManager.qml \
    qml/lib/PresetStorage.js \
    qml/lib/SessionManager.js \
    qml/lib/TokenStorage.js \
    qml/lib/UrlRouter.js \
    qml/lib/VideoExpansionTracker.js \
    qml/lib/qmldir \
    qml/fonts/FiraSans-Bold.ttf \
    qml/fonts/FiraSans-Light.ttf \
    qml/fonts/FiraSans-Regular.ttf \
    qml/fonts/Inter-Bold.ttf \
    qml/fonts/Inter-Light.ttf \
    qml/fonts/Inter-Regular.ttf \
    qml/fonts/OFL-FiraSans.txt \
    qml/fonts/OFL-Inter.txt \
    qml/fonts/OFL-OpenSans.txt \
    qml/fonts/OFL-Roboto.txt \
    qml/fonts/OFL-Ubuntu.txt \
    qml/fonts/OpenSans-Bold.ttf \
    qml/fonts/OpenSans-Light.ttf \
    qml/fonts/OpenSans-Regular.ttf \
    qml/fonts/Roboto-Bold.ttf \
    qml/fonts/Roboto-Light.ttf \
    qml/fonts/Roboto-Regular.ttf \
    qml/fonts/Ubuntu-Bold.ttf \
    qml/fonts/Ubuntu-Light.ttf \
    qml/fonts/Ubuntu-Regular.ttf \
    rpm/harbour-meridon.changes.in \
    rpm/harbour-meridon.changes.run.in \
    rpm/harbour-meridon.spec \
    translations/*.ts \
    harbour-meridon.desktop \
    harbour-meridon-open-url.desktop \
    LICENSE

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

# to disable building translations every time, comment out the
# following CONFIG line
CONFIG += sailfishapp_i18n

# German translation is enabled as an example. If you aren't
# planning to localize your app, remember to comment out the
# following TRANSLATIONS line. And also do not forget to
# modify the localized app name in the the .desktop file.
#TRANSLATIONS += translations/harbour-meridon-de.ts
