// El renderizador de la suite.
//
// Carga un .qml, lo deja correr unos milisegundos para que sus timers lleguen a
// disparar, y guarda lo que se dibujó como PNG. Eso es lo que permite que los
// tests pregunten "¿salieron píxeles?" en vez de "¿construye y reporta un
// tamaño?" - las dos preguntas que daban que sí mientras el widget era
// invisible en el panel.
//
// Existe porque el binario estaba en el árbol y su fuente NO: run.sh lo
// recompila si falta, así que sin este archivo un clon nuevo no puede correr un
// solo test.
//
//   g++ -fPIC -O1 -o render render.cpp $(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Gui Qt6Core)
//   ./render Archivo.qml salida.png [ms]
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlError>
#include <QTimer>
#include <QImage>
#include <QUrl>
#include <QDebug>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);

    if (argc < 3) {
        qWarning().noquote() << "uso: render Archivo.qml salida.png [ms]";
        return 2;
    }

    const QString source = QString::fromLocal8Bit(argv[1]);
    const QString output = QString::fromLocal8Bit(argv[2]);
    const int settleMs = (argc > 3) ? QString::fromLocal8Bit(argv[3]).toInt() : 1000;

    QQuickView view;
    // El tamaño lo manda la raíz del QML, no el que la abre: cada test declara
    // el suyo y las cuentas de píxeles dependen de que se respete.
    view.setResizeMode(QQuickView::SizeViewToRootObject);
    view.setSource(QUrl::fromLocalFile(source));

    if (view.status() == QQuickView::Error) {
        const auto errors = view.errors();
        for (const QQmlError &e : errors)
            qWarning().noquote() << "QML ERROR:" << e.toString();
        return 1;
    }

    view.show();

    int exitCode = 0;
    QTimer::singleShot(settleMs, &app, [&]() {
        const QImage shot = view.grabWindow();
        if (shot.isNull() || !shot.save(output)) {
            qWarning().noquote() << "no se pudo guardar" << output;
            exitCode = 1;
        } else {
            qInfo().noquote() << QStringLiteral("saved %1 %2 x %3")
                                     .arg(output).arg(shot.width()).arg(shot.height());
        }
        app.quit();
    });

    app.exec();
    return exitCode;
}
