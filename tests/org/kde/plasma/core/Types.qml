import QtQuick

// PlasmaCore.Types. In Plasma these are C++ enums; a QML enum is exposed the
// same way - as TypeName.Value - which is how the widgets reach them. They
// cannot be plain properties: QML forbids an upper-case property name.
QtObject {
    enum FormFactor {
        Planar = 0,
        MediaCenter = 1,
        Horizontal = 2,
        Vertical = 3
    }

    enum ItemStatus {
        UnknownStatus = 0,
        PassiveStatus = 1,
        ActiveStatus = 2,
        NeedsAttentionStatus = 3,
        RequiresAttentionStatus = 4,
        AcceptingInputStatus = 5,
        HiddenStatus = 6
    }
}
