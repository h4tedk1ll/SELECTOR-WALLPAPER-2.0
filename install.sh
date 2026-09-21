#!/usr/bin/env bash
# Instalador de Gothic Wallpaper Selector
set -e

APP_DIR="$HOME/wallpaper-selector-qml"
WP_DIR="$HOME/Wallpapers"

echo "🖤 Wallpaper Selector — instalador"
echo ""

echo "📦 [1/4] Dependencias python..."
pip install --user --break-system-packages -r requirements.txt 2>/dev/null \
  || pip install --user -r requirements.txt

echo "🖼️  [2/4] Verificando feh..."
if ! command -v feh >/dev/null 2>&1; then
  echo "   feh no está instalado. Instálalo con: sudo apt install feh"
  exit 1
fi

echo "📁 [3/4] Copiando app a $APP_DIR..."
mkdir -p "$APP_DIR"
cp selector.py Main.qml WallpaperItem.qml "$APP_DIR/"
mkdir -p "$APP_DIR/assets"
cp assets/*.png "$APP_DIR/assets/" 2>/dev/null || true
mkdir -p "$WP_DIR"

echo "⌨️  [4/4] Atajo sugerido para sxhkd (~/.config/sxhkd/sxhkdrc):"
echo ""
echo "    super + shift + w"
echo "        python3 $APP_DIR/selector.py"
echo ""
echo "   Recarga con: pkill -USR1 -x sxhkd"
echo ""
echo "✅ Listo. Corre: python3 $APP_DIR/selector.py"
