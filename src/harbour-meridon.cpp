#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem>
#include <QScopedPointer>
#include <QtQml>
#include <QMetaObject>
#include <QVariant>

#include "mediauploader.h"
#include "urlrouter.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    QScopedPointer<QQuickView> view(SailfishApp::createView());

    qmlRegisterType<MediaUploader>("harbour.meridon.Native", 1, 0, "MediaUploader");

    view->setSource(SailfishApp::pathToMainQml());
    view->show();

    UrlRouter urlRouter;
    urlRouter.registerService(); // logs its own success/failure - see urlrouter.cpp

    QObject::connect(&urlRouter, &UrlRouter::urlReceived, view.data(), [&view](const QString &url) {
        qWarning() << "UrlRouter: urlReceived, forwarding to QML:" << url;
        view->raise();
        view->requestActivate();
        QObject *root = view->rootObject();
        bool invoked = QMetaObject::invokeMethod(root, "handleIncomingUrl", Q_ARG(QVariant, url));
        if (!invoked)
            qWarning() << "UrlRouter: failed to invoke handleIncomingUrl on QML root";
    });

    return app->exec();
}
