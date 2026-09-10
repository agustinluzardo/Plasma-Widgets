import QtQuick
// TasksModel, with just enough of the model API for a window count.
QtObject {
    enum GroupMode {
        GroupDisabled = 0,
        GroupApplications = 1,
        GroupApplicationsInline = 2
    }

    property int groupMode: TasksModel.GroupMode.GroupDisabled
    property int count: 0
    property var rows: []       // each entry: { desktops: [id, ...] }
    signal dataChanged()
    function index(row, col) { return row }
    function data(row, role) { return rows[row] ? rows[row].desktops : [] }
    onRowsChanged: count = rows.length
}
