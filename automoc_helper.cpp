#include <QCoreApplication>
#include <QDir>
#include <QStringList>
#include <iostream>

void findMocJsonFiles(const QString &path, const QString &relativePath = QString()) {
    QDir dir(path);
    foreach (const QString &entry, dir.entryList(QDir::Files | QDir::NoDotAndDotDot)) {
        if (entry.startsWith("moc") && entry.endsWith(".json")) {
            std::cout << (relativePath + entry).toStdString() << "\n";
        }
    }

    foreach (const QString &entry, dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        findMocJsonFiles(path + QDir::separator() + entry, relativePath + QDir::separator() + entry + QDir::separator());
    }
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);

    QStringList arguments = app.arguments();
    if (arguments.count() < 2) {
        std::cerr << "Usage: " << argv[0] << " path_to_automoc_directory\n";
        return 1;
    }

    QString startDirectory = arguments.at(1);
    findMocJsonFiles(startDirectory,startDirectory);
    std::cout << std::endl; 
    return 0;
}
