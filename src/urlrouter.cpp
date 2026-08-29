#include "urlrouter.h"

#include <QDBusConnection>
#include <QDBusError>
#include <QDebug>

namespace {
// same as in desktop file
const char *ServiceName = "org.anttsam.meridon";
const char *ObjectPath = "/org/anttsam/meridon";
}

UrlRouter::UrlRouter(QObject *parent) : QObject(parent)
{
}

bool UrlRouter::registerService()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qWarning() << "UrlRouter: session bus not connected:" << bus.lastError().message();
        return false;
    }
    if (!bus.registerObject(ObjectPath, this, QDBusConnection::ExportScriptableSlots)) {
        qWarning() << "UrlRouter: registerObject failed:" << bus.lastError().message();
        return false;
    }
    if (!bus.registerService(ServiceName)) {
        qWarning() << "UrlRouter: registerService failed:" << bus.lastError().message();
        return false;
    }
    qWarning() << "UrlRouter: registered" << ServiceName << "at" << ObjectPath;
    return true;
}

void UrlRouter::openUrl(const QStringList &urls)
{
    qWarning() << "UrlRouter: openUrl() called with" << urls;
    if (!urls.isEmpty())
        emit urlReceived(urls.first());
}
