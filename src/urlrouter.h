#ifndef URLROUTER_H
#define URLROUTER_H

#include <QObject>
#include <QStringList>

// Session-bus receiver for URLs handed to this app
class UrlRouter : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.anttsam.meridon")

public:
    explicit UrlRouter(QObject *parent = nullptr);

    bool registerService();

public slots:
    Q_SCRIPTABLE void openUrl(const QStringList &urls);

signals:
    void urlReceived(const QString &url);
};

#endif // URLROUTER_H
