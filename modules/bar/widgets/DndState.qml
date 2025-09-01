pragma Singleton
import QtQml

QtObject {
    id: dnd
    // unica fonte di verità del DND, viva per tutta la sessione
    property bool dnd: false
}
