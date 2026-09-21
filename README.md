# 🖤 Gothic Wallpaper Selector

Selector de wallpapers con estética gótica/victoriana para Linux + bspwm (y cualquier WM de X11). Carrusel estilo coverflow sobre fondo difuminado, marco ornamentado que funciona como buscador, y firma automática con tu nombre de usuario.

![estilo](https://img.shields.io/badge/estilo-gótico-black) ![qt](https://img.shields.io/badge/Qt-6_QML-green) ![wm](https://img.shields.io/badge/WM-bspwm-red)

## ✨ Características

- 🔍 **Buscador funcional** con marco ornamentado (filtra mientras escribes)
- 🎞️ **Carrusel coverflow** — el fondo central grande, laterales más pequeños y caídos
- 🌫️ **Fondo difuminado animado** que sigue al wallpaper seleccionado (crossfade)
- 👀 **Preview en vivo** al navegar, sin tocar tus colores
- 🎨 Al confirmar (`Enter`) aplica el fondo y regenera los colores con **pywal**
- ✍️ **Firma automática** con tu nombre de usuario (la detecta sola)
- ⌨️ Atajos de teclado, rueda del ratón y clic

## 📋 Requisitos

- 🐧 Linux con X11 (probado en Kali + bspwm)
- 🐍 Python 3.10+
- 🖼️ `feh` para poner los fondos
- 🎨 [`pywal`](https://github.com/dylanaraps/pywal) + script `themes` (para regenerar colores al confirmar)
- 📦 `PySide6-Essentials` y `Pillow` (se instalan solos con el instalador)

## 🚀 Instalación paso a paso

### 1️⃣ Clona el repo

```bash
git clone https://github.com/h4tedk1ll/gothic-wallpaper-selector.git
cd gothic-wallpaper-selector
```

### 2️⃣ Instala las dependencias del sistema

```bash
sudo apt update && sudo apt install -y feh python3-pip
# pywal (si no lo tienes):
pip install --user pywal
```

> 💡 Necesitas tu script `themes` en el `PATH` (el que corre `wal` + ajusta polybar). Si no lo tienes, el selector igual navega y previsualiza, solo no regenerará colores al confirmar.

### 3️⃣ Corre el instalador

```bash
chmod +x install.sh
./install.sh
```

Esto hace por ti:
- ✅ Instala `PySide6-Essentials` y `Pillow` con pip
- ✅ Copia la app a `~/wallpaper-selector-qml/`
- ✅ Deja tus fondos en `~/Wallpapers/` (la carpeta que usa el selector)

### 4️⃣ Asigna el atajo de teclado

Si usas **sxhkd** (bspwm), agrega a tu `~/.config/sxhkd/sxhkdrc`:

```
# Gothic Wallpaper Selector
super + shift + w
    python3 ~/wallpaper-selector-qml/selector.py
```

Y recarga los atajos:

```bash
pkill -USR1 -x sxhkd
```

> 🪟 ¿Otro WM? Solo bindea esa misma línea al comando con tu método (i3, Openbox, etc.).

### 5️⃣ Pruébalo

Pulsa `Super + Shift + W`. Deberías ver la tira sobre tu fondo difuminado. ¡Listo! 🎉

## ⌨️ Uso

| Tecla | Acción |
|-------|--------|
| `←` `→` / rueda / clic | Navegar (con preview en vivo) |
| Escribir | Filtrar wallpapers |
| `Enter` / clic en el centro | ✅ Aplicar fondo + regenerar colores |
| `Esc` / clic fuera | ❌ Cancelar (restaura tu fondo) |

## 🎨 Personalización

- 🖼️ **Ornamentos**: cambia los PNG en `assets/` (`frame_top.png`, `fairy_left.png`, `fairy_right.png`) por los tuyos, manteniendo fondo transparente.
- ✒️ **Fuente de la firma**: si tienes la fuente `Railey` (`.ttf`/`.otf`), suéltala en `assets/` y se usa sola. Si no, usa un fallback delineado.
- ✍️ **La firma** sale sola con tu usuario (`whoami` en mayúsculas). Nada que configurar.
- ⏱️ **Velocidad del fade**: ajusta `duration` de `fadeAnim` en `Main.qml`.

## 🗂️ Estructura

```
gothic-wallpaper-selector/
├── selector.py          # backend: lista, filtra, preview, aplica, blur
├── Main.qml             # ventana, tira coverflow, buscador, firma
├── WallpaperItem.qml    # delegate de cada fondo
├── assets/              # marco + hadas + fuente opcional
├── install.sh           # instalador
└── requirements.txt     # dependencias python
```

## 📄 Licencia

MIT — úsalo y modifícalo libremente. Si te gusta, una ⭐ se agradece.

## 👤 Autor

Hecho por **h4tedk1ll** 🖤
