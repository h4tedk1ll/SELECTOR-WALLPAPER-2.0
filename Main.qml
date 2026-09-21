import QtQuick
import QtQuick.Window

// Estetica gotica del usuario (assets de Canva) sobre la mecanica Caelestia:
// - Fondo difuminado del wallpaper seleccionado, con crossfade animado.
// - Marco ornamentado arriba (decorativo), hadas laterales.
// - Tira de 5 items NO recta: laterales mas pequenos y caidos (atributos
//   squeeze/hgt/yOff interpolados en el path).
// - Firma H4TEDK1LL abajo del centro (fuente Railey si existe en assets/).
// - Preview live 100ms (feh). Enter confirma (feh + themes), Esc/clic-fuera
//   cancela restaurando el original. R = aleatorio.
Window {
    id: mainWindow
    visible: true
    visibility: Window.FullScreen
    flags: Qt.FramelessWindowHint
    color: "black"
    title: "wallpaper-selector"

    property bool busy: false
    property string pendingPath: ""
    property string lastGood: ""
    property bool fading: false

    function currentUrl() {
        if (carousel.count > 0 && carousel.currentIndex >= 0)
            return carousel.model[carousel.currentIndex];
        return "";
    }

    function showWallpaper(blurUrl) {
        if (!blurUrl || blurUrl === pendingPath)
            return;
        pendingPath = blurUrl;
        if (fading) {
            fadeAnim.stop();
            wallFront.source = lastGood !== "" ? lastGood : wallBack.source;
            wallFront.opacity = 1;
            fading = false;
        }
        wallBack.source = blurUrl;
    }

    function startFade() {
        if (fading)
            return;
        fading = true;
        fadeAnim.restart();
    }

    function confirmCurrent() {
        if (busy || carousel.count === 0)
            return;
        busy = true;
        caption.text = "✦ APLICANDO ✦";
        backend.confirm(currentUrl());
    }

    function doCancel() {
        if (busy)
            return;
        busy = true;
        if (backend.originalBg !== "")
            showWallpaper(backend.originalBg);
        backend.cancel();
        quitTimer.interval = 500;
        quitTimer.restart();
    }

    function randomPick() {
        if (!busy && carousel.count > 0)
            carousel.currentIndex = Math.floor(Math.random() * carousel.count);
    }

    // ---------- fondo difuminado con crossfade ----------
    Image {
        id: wallBack
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        onStatusChanged: {
            if (status === Image.Ready) {
                lastGood = source;
                if (source !== wallFront.source)
                    startFade();
            }
        }
    }
    Image {
        id: wallFront
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }
    NumberAnimation {
        id: fadeAnim
        target: wallFront
        property: "opacity"
        from: 1; to: 0
        duration: 300
        easing.type: Easing.OutCubic
        onFinished: {
            wallFront.source = wallBack.source;
            wallFront.opacity = 1;
            fading = false;
        }
    }

    // clic fuera de la tira = cancelar
    MouseArea {
        anchors.fill: parent
        onClicked: mainWindow.doCancel()
        onWheel: (wheel) => {
            if (busy)
                return;
            if (wheel.angleDelta.y > 0)
                carousel.decrementCurrentIndex();
            else if (wheel.angleDelta.y < 0)
                carousel.incrementCurrentIndex();
        }
    }

    // ---------- marco ornamentado superior = BUSCADOR ----------
    Item {
        id: searchBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.13
        width: Math.min(720, parent.width * 0.42)
        height: width * 253 / 827

        Image {
            id: frameImg
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: "assets/frame_top.png"
            asynchronous: true
            cache: true
        }
        // campo de texto transparente sobre el interior blanco del marco
        TextInput {
            id: searchInput
            anchors.fill: parent
            anchors.leftMargin: parent.width * 0.12
            anchors.rightMargin: parent.width * 0.14
            anchors.topMargin: parent.height * 0.30
            anchors.bottomMargin: parent.height * 0.26
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            color: "#141414"
            selectionColor: "#c8102e"
            selectedTextColor: "white"
            cursorVisible: activeFocus
            cursorDelegate: Rectangle { width: 2; color: "#141414" }
            font.pixelSize: Math.max(14, parent.width * 0.035)
            focus: true
            onTextChanged: backend.setQuery(text)
            Keys.onLeftPressed: (e) => { if (!busy) carousel.decrementCurrentIndex(); e.accepted = true; }
            Keys.onRightPressed: (e) => { if (!busy) carousel.incrementCurrentIndex(); e.accepted = true; }
            Keys.onReturnPressed: mainWindow.confirmCurrent()
            Keys.onEnterPressed: mainWindow.confirmCurrent()
            Keys.onEscapePressed: mainWindow.doCancel()
        }
        Text {
            anchors.fill: searchInput
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: "Buscar wallpaper…"
            color: "#8a8a8a"
            font.pixelSize: searchInput.font.pixelSize
            visible: searchInput.text === ""
        }
    }

    // ---------- hadas laterales ----------
    Image {
        x: -24
        y: parent.height * 0.50
        width: 280
        fillMode: Image.PreserveAspectFit
        source: "assets/fairy_left.png"
        asynchronous: true
        cache: true
    }
    Image {
        x: parent.width - width + 24
        y: parent.height * 0.50
        width: 280
        fillMode: Image.PreserveAspectFit
        source: "assets/fairy_right.png"
        asynchronous: true
        cache: true
    }

    // ---------- tira natural (5 items, curva visual) ----------
    PathView {
        id: carousel
        objectName: "carousel"
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.585
        width: Math.min(1240, parent.width - 80)
        height: 360
        model: backend ? backend.walls : []
        delegate: wallDelegate
        pathItemCount: 5
        cacheItemCount: 2
        snapMode: PathView.SnapToItem
        highlightRangeMode: PathView.StrictlyEnforceRange
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        onCurrentItemChanged: previewTimer.restart()

        path: Path {
            startX: 0
            startY: carousel.height / 2
            PathLine { x: carousel.width * 0.25; y: carousel.height / 2 }
            PathLine { x: carousel.width / 2; y: carousel.height / 2 }
            PathLine { x: carousel.width * 0.75; y: carousel.height / 2 }
            PathLine { x: carousel.width; y: carousel.height / 2 }
        }
    }

    Component {
        id: wallDelegate
        WallpaperItem {
            baseW: 460
            baseH: 270
            onChosen: (idx, isCur) => {
                if (busy)
                    return;
                if (isCur)
                    mainWindow.confirmCurrent();
                else
                    carousel.currentIndex = idx;
            }
        }
    }

    // ---------- firma ----------
    FontLoader {
        id: railey
        source: backend ? backend.fontUrl : ""
    }
    Text {
        id: caption
        anchors.horizontalCenter: parent.horizontalCenter
        y: carousel.y + carousel.height / 2 + 168
        text: backend ? backend.userName : ""
        color: "white"
        style: Text.Outline
        styleColor: "#0a0a0c"
        font.family: railey.status === FontLoader.Ready ? railey.name : "Noto Sans Display"
        font.weight: Font.ExtraBold
        font.pixelSize: 44
        font.letterSpacing: 6
    }

    // ---------- teclado (respaldo si el buscador pierde foco) ----------
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: false
        Keys.onLeftPressed: { if (!busy) carousel.decrementCurrentIndex(); }
        Keys.onRightPressed: { if (!busy) carousel.incrementCurrentIndex(); }
        Keys.onReturnPressed: mainWindow.confirmCurrent()
        Keys.onEnterPressed: mainWindow.confirmCurrent()
        Keys.onEscapePressed: mainWindow.doCancel()
    }

    Timer {
        id: previewTimer
        interval: 100
        onTriggered: {
            var u = currentUrl();
            if (u === "")
                return;
            backend.preview(u);
            backend.requestBg(u);
        }
    }

    Timer {
        id: quitTimer
        interval: 500
        onTriggered: Qt.quit()
    }

    Connections {
        target: backend
        function onWallsChanged() {
            if (carousel.count === 0) {
                carousel.currentIndex = -1;
                return;
            }
            // como Caelestia: filtrando se va al primero,
            // sin filtro se centra en el actual
            carousel.currentIndex = searchInput.text.trim() === ""
                ? backend.indexOfOriginal()
                : 0;
        }
        function onBgChanged(blurUrl) {
            showWallpaper(blurUrl);
        }
        function onApplyFinished() {
            quitTimer.interval = 450;
            quitTimer.restart();
        }
    }

    Component.onCompleted: {
        var start = backend.currentBg;
        pendingPath = start;
        lastGood = start;
        wallFront.source = start;
        wallBack.source = start;
        carousel.currentIndex = backend.initialIndex;
        searchInput.forceActiveFocus();
    }
}
