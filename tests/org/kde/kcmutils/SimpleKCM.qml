import QtQuick
import QtQuick.Controls as QQC2

// KCM.SimpleKCM: a scrollable page for a settings module. Its whole job here is
// to make a long form reachable without resizing the dialog, so the mock is a
// Flickable - which is what it is underneath.
QQC2.ScrollView {
    default property alias contentItemData: inner.data
    Item { id: inner; width: parent ? parent.width : 0 }
}
