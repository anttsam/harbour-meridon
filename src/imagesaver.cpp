#include "imagesaver.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QMimeType>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>

namespace {

const qint64 MaxImageBytes = 64 * 1024 * 1024;

// Keeps letters, digits and a few safe punctuation characters, so a name taken
// from a URL can't hold path separators or other surprises.
QString sanitizedBaseName(const QString &name)
{
    QString out = name;
    out.replace(QRegularExpression(QStringLiteral("[^\\w\\-. ]")), QStringLiteral("_"));
    out = out.trimmed();
    while (out.startsWith(QLatin1Char('.')))
        out.remove(0, 1);
    if (out.size() > 80)
        out.truncate(80);
    return out;
}

// "name.jpg", then "name (1).jpg", "name (2).jpg" ... never overwrites
QString uniquePath(const QDir &dir, const QString &base, const QString &suffix)
{
    const QString ext = suffix.isEmpty() ? QString() : QLatin1Char('.') + suffix;
    QString candidate = dir.filePath(base + ext);
    for (int i = 1; QFileInfo::exists(candidate) && i < 10000; ++i)
        candidate = dir.filePath(QStringLiteral("%1 (%2)%3").arg(base).arg(i).arg(ext));
    return candidate;
}

}

ImageSaver::ImageSaver(QObject *parent)
    : QObject(parent)
{
}

QString ImageSaver::defaultDirectory() const
{
    const QString pictures = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    return pictures.isEmpty() ? QString() : pictures + QStringLiteral("/Meridon");
}

void ImageSaver::save(const QString &url, const QString &directory)
{
    const QUrl source = QUrl::fromUserInput(url);
    if (!source.isValid() || url.isEmpty()) {
        fail(QStringLiteral("Invalid url"));
        return;
    }

    if (source.isLocalFile()) {
        QFile file(source.toLocalFile());
        if (!file.open(QIODevice::ReadOnly)) {
            fail(QStringLiteral("Couldn't open local file"));
            return;
        }
        if (file.size() > MaxImageBytes) {
            fail(QStringLiteral("Local file too large"));
            return;
        }
        finish(QFileInfo(file).completeBaseName(), file.readAll(), directory);
        return;
    }

    if (source.scheme() != QLatin1String("https") && source.scheme() != QLatin1String("http")) {
        fail(QStringLiteral("Unsupported url scheme"));
        return;
    }

    QNetworkRequest request(source);
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    QNetworkReply *reply = m_manager.get(request);

    connect(reply, &QNetworkReply::downloadProgress, reply, [reply](qint64 received, qint64) {
        if (received > MaxImageBytes)
            reply->abort();
    });

    connect(reply, &QNetworkReply::finished, this, [this, reply, source, directory]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            fail(reply->errorString());
            return;
        }
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status >= 400) {
            fail(QStringLiteral("HTTP %1").arg(status));
            return;
        }
        finish(QFileInfo(source.path()).completeBaseName(), reply->readAll(), directory);
    });
}

void ImageSaver::finish(const QString &sourceName, const QByteArray &data, const QString &directory)
{
    // Decide the type from the bytes, not from the URL or Content-Type: an
    // error page saved as "photo.jpg" would be worse than a clear failure.
    QMimeDatabase mimeDb;
    const QMimeType mime = mimeDb.mimeTypeForData(data);
    if (data.isEmpty() || !mime.name().startsWith(QLatin1String("image/"))) {
        fail(QStringLiteral("Not an image (%1)").arg(mime.name()));
        return;
    }

    QString suffix = mime.preferredSuffix();
    if (suffix.isEmpty())
        suffix = QStringLiteral("jpg");

    QString base = sanitizedBaseName(sourceName);
    if (base.isEmpty())
        base = QStringLiteral("meridon-image");

    const QString target = directory.isEmpty() ? defaultDirectory() : directory;
    if (target.isEmpty()) {
        fail(QStringLiteral("No target folder"));
        return;
    }
    QDir dir(target);
    if (!dir.mkpath(QStringLiteral("."))) {
        fail(QStringLiteral("Couldn't create ") + dir.path());
        return;
    }

    const QString path = uniquePath(dir, base, suffix);
    QSaveFile out(path);
    if (!out.open(QIODevice::WriteOnly)
            || out.write(data) != data.size()
            || !out.commit()) {
        fail(QStringLiteral("Couldn't write ") + path + QStringLiteral(": ") + out.errorString());
        return;
    }

    emit saved(QFileInfo(path).fileName());
}

void ImageSaver::fail(const QString &why)
{
    qWarning() << "ImageSaver:" << why;
    emit failed();
}
