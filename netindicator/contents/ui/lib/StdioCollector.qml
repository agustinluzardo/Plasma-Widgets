import QtQuick

// Quickshell's StdioCollector: the whole stream, once it has ended.
QtObject {
    property string text: ""
    signal streamFinished()
}
