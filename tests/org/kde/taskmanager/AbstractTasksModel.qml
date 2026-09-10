import QtQuick

// The role enum TasksModel is queried with. In Plasma this is a C++ enum on
// AbstractTasksModel; a QML enum is exposed the same way - as TypeName.Value -
// which is exactly how the code under test reaches it.
QtObject {
    enum AdditionalRoles {
        VirtualDesktops = 1
    }
}
