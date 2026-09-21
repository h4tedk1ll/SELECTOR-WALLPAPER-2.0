import QtQuick

// Tira natural (no recta): tamano discreto por estado — el actual grande,
// los laterales mas pequenos y caidos, con transicion animada.
// (Geometria fija por item: evita loops de layout en el PathView.)
Item {
    id: root

    property string fileUrl: modelData
    property bool isCurrent: PathView.isCurrentItem
    property int baseW: 460
    property int baseH: 270

    signal chosen(int idx, bool isCur)

    width: baseW
    height: baseH + 80
    z: isCurrent ? 1 : 0

    Rectangle {
        anchors.centerIn: imgBox
        width: imgBox.width + 8
        height: imgBox.height + 8
        color: "black"
        opacity: isCurrent ? 0.5 : 0.35
        y: imgBox.y + 4
    }

    Rectangle {
        id: imgBox
        anchors.centerIn: parent
        anchors.verticalCenterOffset: isCurrent ? 0 : 24
        width: isCurrent ? baseW : 150
        height: isCurrent ? baseH : 232
        clip: true
        color: "#1a1d24"
        border.width: isCurrent ? 2 : 1
        border.color: isCurrent ? "#f2f2f2" : "#3a3d46"

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Image {
            anchors.fill: parent
            source: root.fileUrl
            asynchronous: true
            cache: true
            smooth: !root.PathView.view.moving
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 480
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chosen(index, isCurrent)
    }
}
