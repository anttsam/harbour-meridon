#ifndef IMAGESAVER_H
#define IMAGESAVER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QString>

// Saves a picture shown in the image viewer to the chosen folder, by default
// ~/Pictures/Meridon (where the Gallery picks it up). Plain QML has no way to
// write binary files, so this does the download (or the copy, for a local
// file://) natively.
// Needs the UserDirs permission, which the .desktop file already has.
class ImageSaver : public QObject
{
    Q_OBJECT

public:
    explicit ImageSaver(QObject *parent = nullptr);

    // ~/Pictures/Meridon: used when the user hasn't chosen a folder
    Q_INVOKABLE QString defaultDirectory() const;

    // directory is the folder from the settings ("" for the default one).
    // One save at a time is expected - the viewer disables its button while busy.
    Q_INVOKABLE void save(const QString &url, const QString &directory);

signals:
    // fileName is the bare name (not the full path), for the confirmation notice
    void saved(const QString &fileName);
    void failed();

private:
    void finish(const QString &sourceName, const QByteArray &data, const QString &directory);
    void fail(const QString &why);

    QNetworkAccessManager m_manager;
};

#endif // IMAGESAVER_H
