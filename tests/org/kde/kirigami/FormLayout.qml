import QtQuick
import QtQuick.Layouts
// Kirigami.FormLayout: a two-column label/control grid. Modelled as a column
// here, which is enough to prove the page constructs and its bindings resolve.
ColumnLayout {
    // FormData is an attached property on children in the real thing; offscreen
    // the children simply stack.
    spacing: 6
}
