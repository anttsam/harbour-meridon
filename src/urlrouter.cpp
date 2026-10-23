#include "urlrouter.h"

#include <QDBusConnection>
#include <QDBusError>
#include <QDebug>

namespace {
// OrganizationName.ApplicationName from the [X-Sailjail] section of the
// desktop file - sailjaild activates this name, with the path derived from it
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

void UrlRouter::Open(const QStringList &uris, const QVariantMap &platformData)
{
    qWarning() << "UrlRouter: Open() called with" << uris;
    if (uris.isEmpty()) {
        Activate(platformData);
        return;
    }
    emit urlReceived(uris.first());
}

void UrlRouter::Activate(const QVariantMap &platformData)
{
    Q_UNUSED(platformData)
    emit activateRequested();
}
