#ifndef URLROUTER_H
#define URLROUTER_H

#include <QObject>
#include <QStringList>
#include <QVariantMap>

// Session-bus receiver for URLs handed to this app, via the standard
// org.freedesktop.Application interface that X-DBusActivatable=true in
// harbour-meridon.desktop makes the system call (Open for a link, Activate
// for a plain launch while already running).
class UrlRouter : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Application")

public:
    explicit UrlRouter(QObject *parent = nullptr);

    bool registerService();

public slots:
    Q_SCRIPTABLE void Open(const QStringList &uris, const QVariantMap &platformData);
    Q_SCRIPTABLE void Activate(const QVariantMap &platformData);

signals:
    void urlReceived(const QString &url);
    void activateRequested();
};

#endif // URLROUTER_H
