#!/usr/bin/env python3
"""Backend del selector de wallpapers estilo coverflow.

- Lista ~/Wallpapers, filtra por query.
- requestBg(wallUrl): genera version difuminada (cache en disco) y avisa con
  bgChanged. Solo el ultimo pedido emite (token), vecinos se precargan.
- preview(path): feh --bg-fill en hilo (no destructivo, sin pywal).
- confirm(path): feh + `themes` (pywal) en hilo, avisa con finished.
- cancel(): restaura el fondo original con feh.
"""
import json
import os
import shlex
import subprocess
import sys
import threading
from pathlib import Path

from PIL import Image, ImageOps, ImageFilter
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl, QTimer

LOCK_FILE = Path("/tmp/wallpaper-selector.lock")
CACHE_DIR = Path.home() / ".cache" / "wallpaper-selector"
CACHE_DIR.mkdir(parents=True, exist_ok=True)
WP_DIR = Path.home() / "Wallpapers"
EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def acquire_lock():
    try:
        if LOCK_FILE.exists():
            try:
                pid = int(LOCK_FILE.read_text().strip())
                os.kill(pid, 0)
                print("Wallpaper selector already running!")
                sys.exit(0)
            except (ValueError, ProcessLookupError, OSError):
                LOCK_FILE.unlink(missing_ok=True)
        LOCK_FILE.write_text(str(os.getpid()))
        return True
    except Exception as e:
        print(f"Lock error: {e}")
        return False


def release_lock():
    try:
        LOCK_FILE.unlink(missing_ok=True)
    except Exception:
        pass


def load_pywal():
    try:
        data = json.loads((Path.home() / ".cache" / "wal" / "colors.json").read_text())
        sp, co = data["special"], data["colors"]
        return {"bg": sp["background"], "fg": sp.get("foreground", "#e6e1e7"),
                "accent": co.get("color1", "#c8102e"), "dim": co.get("color8", "#3b2a5e")}
    except Exception:
        return {"bg": "#14161b", "fg": "#e6e1e7", "accent": "#c8102e", "dim": "#3b2a5e"}


def lighten(hexcol, amt=0x12):
    try:
        h = hexcol.lstrip("#")
        r, g, b = (min(255, int(h[i:i + 2], 16) + amt) for i in (0, 2, 4))
        return f"#{r:02x}{g:02x}{b:02x}"
    except Exception:
        return hexcol


def current_wallpaper():
    try:
        wal = (Path.home() / ".cache" / "wal" / "wal").read_text().strip().split("\n")[0]
        if wal and Path(wal).exists():
            return Path(wal)
    except Exception:
        pass
    try:
        parts = shlex.split((Path.home() / ".fehbg").read_text())
        for p in reversed(parts):
            if Path(p).exists() and Path(p).suffix.lower() in EXTS:
                return Path(p)
    except Exception:
        pass
    return None


def to_url(p: Path) -> str:
    return QUrl.fromLocalFile(str(p)).toString()


def cache_key(wp: Path) -> str:
    import hashlib
    try:
        st = wp.stat()
        raw = f"{wp}|{st.st_mtime_ns}|{st.st_size}".encode()
    except OSError:
        raw = str(wp).encode()
    return hashlib.md5(raw).hexdigest()


def make_blur(wp: Path) -> Path | None:
    """Version difuminada 960x540 para el fondo (cache en disco)."""
    out = CACHE_DIR / f"b_{cache_key(wp)}.jpg"
    if out.exists():
        return out
    try:
        with Image.open(wp) as im:
            im = ImageOps.fit(im.convert("RGB"), (960, 540), Image.BILINEAR)
            small = im.resize((240, 135), Image.BILINEAR)
            small = small.filter(ImageFilter.GaussianBlur(14))
            small.resize((960, 540), Image.BILINEAR).save(out, "JPEG", quality=70)
        return out
    except Exception as e:
        print(f"blur err {wp.name}: {e}")
        return None


class Backend(QObject):
    wallsChanged = Signal()
    applyFinished = Signal()
    bgChanged = Signal(str)

    def __init__(self):
        super().__init__()
        try:
            self._all = sorted(
                f for f in WP_DIR.iterdir()
                if f.suffix.lower() in EXTS and not f.name.startswith("."))
        except OSError:
            self._all = []
        self.original = current_wallpaper()
        self.original_url = to_url(self.original) if self.original else ""
        self._query = ""
        self._walls = [to_url(p) for p in self._all]
        pal = load_pywal()
        self._bg = pal["bg"]
        self._surface = lighten(pal["bg"], 0x0A)
        self._surface2 = lighten(pal["bg"], 0x22)
        self._fg = pal["fg"]
        self._accent = pal["accent"]
        self._dim = pal["dim"]
        self._closing = False
        # fondo difuminado inicial (sincrono, del wallpaper actual)
        first = self.original or (self._all[0] if self._all else None)
        b = make_blur(first) if first else None
        self._current_bg = to_url(b) if b else ""
        self._bg_token = 0
        self._bg_last_req = ""
        self._font_url = self._find_font()

    # ---------- propiedades ----------
    @Property("QStringList", notify=wallsChanged)
    def walls(self):
        return self._walls

    @Property(str, constant=True)
    def originalUrl(self):
        return self.original_url

    @Property(int, constant=True)
    def initialIndex(self):
        if self.original and self.original_url in self._walls:
            return self._walls.index(self.original_url)
        return 0

    @Property(int, constant=True)
    def totalCount(self):
        return len(self._all)

    @Property(str, constant=True)
    def bg(self):
        return self._bg

    @Property(str, constant=True)
    def surface(self):
        return self._surface

    @Property(str, constant=True)
    def surface2(self):
        return self._surface2

    @Property(str, constant=True)
    def fg(self):
        return self._fg

    @Property(str, constant=True)
    def accent(self):
        return self._accent

    @Property(str, constant=True)
    def dim(self):
        return self._dim

    @Property(str, notify=bgChanged)
    def currentBg(self):
        return self._current_bg

    @Property(str, constant=True)
    def originalBg(self):
        if self.original:
            b = make_blur(self.original)
            if b:
                return to_url(b)
        return self._current_bg

    @Property(str, constant=True)
    def fontUrl(self):
        return self._font_url

    @Property(str, constant=True)
    def userName(self):
        import getpass
        try:
            return getpass.getuser().upper()
        except Exception:
            return "USER"

    @staticmethod
    def _find_font():
        """Busca Railey (ttf/otf). Si el usuario la pone en assets/, se usa."""
        dirs = [Path(__file__).with_name("assets"),
                Path.home() / ".fonts",
                Path.home() / ".local" / "share" / "fonts",
                Path.home() / "Descargas" / "imagenes del selector"]
        for d in dirs:
            try:
                if not d.is_dir():
                    continue
                for f in d.iterdir():
                    if "railey" in f.name.lower() and f.suffix.lower() in (".ttf", ".otf"):
                        return to_url(f)
            except OSError:
                pass
        return ""

    # ---------- slots ----------
    @Slot(result=int)
    def indexOfOriginal(self):
        try:
            return self._walls.index(self.original_url)
        except ValueError:
            return 0

    @Slot(str)
    def requestBg(self, wall_url):
        """Genera el blur en hilo; solo el ultimo pedido emite bgChanged."""
        if self._closing or not wall_url or wall_url == self._bg_last_req:
            if wall_url == self._bg_last_req and self._current_bg:
                return
        self._bg_last_req = wall_url
        self._bg_token += 1
        token = self._bg_token

        def work():
            wp = Path(QUrl(wall_url).toLocalFile())
            b = make_blur(wp)
            # precarga vecinos para que el crossfade vaya fluido
            try:
                i = self._walls.index(wall_url)
                for j in (i + 1, i - 1, i + 2, i - 2):
                    if 0 <= j < len(self._walls):
                        make_blur(Path(QUrl(self._walls[j]).toLocalFile()))
            except ValueError:
                pass
            if b and token == self._bg_token and not self._closing:
                self._current_bg = to_url(b)
                self.bgChanged.emit(self._current_bg)

        threading.Thread(target=work, daemon=True).start()

    @Slot(str)
    def setQuery(self, q):
        q = q.strip().lower()
        if q == self._query:
            return
        self._query = q
        if q:
            self._walls = [to_url(p) for p in self._all if q in p.name.lower()]
        else:
            self._walls = [to_url(p) for p in self._all]
        self.wallsChanged.emit()

    @Slot(str)
    def preview(self, url):
        if self._closing or not url:
            return
        path = QUrl(url).toLocalFile()

        def work():
            try:
                subprocess.run(["feh", "--bg-fill", path],
                               capture_output=True, timeout=5)
            except Exception:
                pass

        threading.Thread(target=work, daemon=True).start()

    @Slot(str)
    def confirm(self, url):
        if self._closing or not url:
            return
        self._closing = True
        path = QUrl(url).toLocalFile()

        def work():
            try:
                subprocess.run(["feh", "--bg-fill", path],
                               capture_output=True, timeout=5)
            except Exception:
                pass
            try:
                subprocess.run(["themes", path], capture_output=True, timeout=120)
            except Exception:
                pass
            self.applyFinished.emit()

        threading.Thread(target=work, daemon=True).start()

    @Slot()
    def cancel(self):
        if self._closing:
            return
        self._closing = True
        orig = self.original

        def work():
            if orig and orig.exists():
                try:
                    subprocess.run(["feh", "--bg-fill", str(orig)],
                                   capture_output=True, timeout=5)
                except Exception:
                    pass

        threading.Thread(target=work, daemon=True).start()


def main():
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine

    if not acquire_lock():
        sys.exit(1)
    app = QGuiApplication(sys.argv)
    backend = Backend()
    if not backend._all:
        print("No wallpapers found!")
        release_lock()
        sys.exit(0)
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    qml = Path(__file__).with_name("Main.qml")
    engine.load(str(qml))
    if not engine.rootObjects():
        print("QML load error!")
        release_lock()
        sys.exit(1)
    ret = app.exec()
    release_lock()
    sys.exit(ret)


if __name__ == "__main__":
    main()
