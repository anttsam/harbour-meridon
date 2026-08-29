#ifndef MEDIAUPLOADER_H
#define MEDIAUPLOADER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QString>

// QML's own XMLHttpRequest can't send binary POST bodies on this platform -
// ArrayBuffer support for XMLHttpRequest.send() was only added in Qt 5.10
// (QTBUG-61599), and SailfishOS 5.1 ships Qt 5.6.3. Passing an ArrayBuffer
// there silently falls back to stringifying it, producing garbage instead
// of the actual file bytes. Media upload goes through this native
// QNetworkAccessManager/QHttpMultiPart-based uploader instead.
class MediaUploader : public QObject
{
    Q_OBJECT

public:
    explicit MediaUploader(QObject *parent = nullptr);

    // can have mulitple files uploading at once
    Q_INVOKABLE void upload(const QString &requestId, const QString &instanceUrl,
                             const QString &accessToken, const QString &filePath);

signals:
    void uploadSucceeded(const QString &requestId, const QString &mediaId);
    void uploadFailed(const QString &requestId, int status, const QString &message);

private:
    QNetworkAccessManager m_manager;
};

#endif // MEDIAUPLOADER_H
