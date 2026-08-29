#include "mediauploader.h"

#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QHttpPart>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeDatabase>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

MediaUploader::MediaUploader(QObject *parent)
    : QObject(parent)
{
}

void MediaUploader::upload(const QString &requestId, const QString &instanceUrl,
                            const QString &accessToken, const QString &filePath)
{
    QFile *file = new QFile(filePath);
    if (!file->open(QIODevice::ReadOnly)) {
        delete file;
        emit uploadFailed(requestId, 0, QStringLiteral("Couldn't open file"));
        return;
    }

    QMimeDatabase mimeDb;
    QString mimeType = mimeDb.mimeTypeForFile(filePath).name();
    if (mimeType.isEmpty())
        mimeType = QStringLiteral("application/octet-stream");

    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    QHttpPart filePart;
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, mimeType);
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader,
        QVariant(QStringLiteral("form-data; name=\"file\"; filename=\"%1\"")
            .arg(QFileInfo(filePath).fileName())));
    filePart.setBodyDevice(file);
    file->setParent(multiPart); // multiPart now owns file's lifetime

    multiPart->append(filePart);

    QNetworkRequest request(QUrl(instanceUrl + QStringLiteral("/api/v2/media")));
    request.setRawHeader("Authorization", "Bearer " + accessToken.toUtf8());

    QNetworkReply *reply = m_manager.post(request, multiPart);
    multiPart->setParent(reply); // reply now owns multiPart (and transitively file)

    connect(reply, &QNetworkReply::finished, this, [this, reply, requestId]() {
        reply->deleteLater();

        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray data = reply->readAll();

        // 202 means the upload was accepted but is still being processed
        // returned id is already usable in a status's media_ids either way.
        if (status == 200 || status == 202) {
            QJsonObject obj = QJsonDocument::fromJson(data).object();
            QString mediaId = obj.value(QStringLiteral("id")).toString();
            if (mediaId.isEmpty())
                emit uploadFailed(requestId, status, QStringLiteral("Bad response"));
            else
                emit uploadSucceeded(requestId, mediaId);
        } else {
            QJsonObject obj = QJsonDocument::fromJson(data).object();
            QString message = obj.value(QStringLiteral("error")).toString();
            if (message.isEmpty())
                message = reply->errorString();
            emit uploadFailed(requestId, status, message);
        }
    });
}
