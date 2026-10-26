#!/bin/sh
# build.sh — build backend Go (arm64) & paket modul Magisk TaptapApp-Go.
# CATATAN: hanya arm64. Toolchain Go tanpa NDK tidak bisa link android/arm.
#
# Aset eksternal (tidak ikut repo source) ditaruh di ../assets/:
#   assets/mihomo          — core mihomo android-arm64 (stok 1.19.32)
#   assets/sing-box        — core sing-box android-arm64 (1.14.3)
#   assets/geodata/        — geoip.dat + geosite.dat (MetaCubeX; SATU set bersama)
#   assets/zashboard/      — isi zashboard (dashboard mihomo)
#   assets/scrcpy-server.jar — server scrcpy 5.0.1 resmi (Genymobile) untuk
#     view Scrcpy; layout.sh memindahkannya ke data/bin saat install.
# Semua bisa dioverride lewat env: GO, ASSETS, MIHOMO_BIN, SINGBOX_BIN,
# GEODATA_DIR, ZASHBOARD_DIR.
#
# Sejak v1.0.32 modul SLIM secara default: core/geodata/jar TIDAK dibundel,
# diunduh lewat Tentang setelah instalasi (scrcpy pertama dikunci 5.0.1).
# Sejak v1.0.39 zashboard JUGA tidak dibundel di slim (diunduh lewat
# kotak Download seperti item lain — unduhan tinggal di data/zashboard,
# di luar webui/, agar lolos layout.sh tiap boot).
# FULL=1 mengembalikan paket full lama (semua aset dibundel).
#
# Hasil: dist/taptapapp-go-$VER.zip (siap flash)
#      + dist/taptapapp-go-$VER-source.zip (slim: tanpa zashboard & geodata)
set -e
cd "$(dirname "$0")"
# Versi diambil dari module.prop (satu sumber kebenaran, tak bisa beda).
VER=$(grep -E '^version=' module/module.prop | cut -d= -f2)
[ -n "$VER" ] || { echo "version= tidak ada di module/module.prop"; exit 1; }
GO="${GO:-go}"
# Perbaikan untuk build GitHub: "go" dari PATH (setup-go) harus diterima.
# Logika lama ([ -x "go" ]) hanya lolos bila GO berupa path absolut, karena
# -x menguji file ./go, bukan hasil pencarian PATH — jadi build selalu gagal
# bila go hanya tersedia lewat PATH. Fallback lokal dipertahankan.
if ! command -v "$GO" >/dev/null 2>&1; then
  if [ -x "$HOME/workspace/build/go-tool-127/go/bin/go" ]; then
    GO="$HOME/workspace/build/go-tool-127/go/bin/go"
  else
    echo "Go toolchain tidak ada: $GO"; exit 1
  fi
fi
ASSETS="${ASSETS:-../assets}"
MIHOMO_BIN="${MIHOMO_BIN:-$ASSETS/mihomo}"
SINGBOX_BIN="${SINGBOX_BIN:-$ASSETS/sing-box}"
GEODATA_DIR="${GEODATA_DIR:-$ASSETS/geodata}"
ZASHBOARD_DIR="${ZASHBOARD_DIR:-$ASSETS/zashboard}"
SCRCPY_JAR="${SCRCPY_JAR:-$ASSETS/scrcpy-server.jar}"
FULL="${FULL:-0}"
if [ "$FULL" = "1" ]; then
  for f in "$MIHOMO_BIN" "$SINGBOX_BIN" "$GEODATA_DIR/geoip.dat" "$GEODATA_DIR/geosite.dat" "$SCRCPY_JAR" "$ZASHBOARD_DIR/index.html"; do
    [ -f "$f" ] || { echo "aset hilang: $f (lihat header skrip ini)"; exit 1; }
  done
fi

echo "== backend: android/arm64 == (FULL=$FULL)"
rm -rf module/bin/arm64 && mkdir -p module/bin/arm64
(cd backend && CGO_ENABLED=0 GOOS=android GOARCH=arm64 "$GO" build -trimpath -ldflags "-s -w -X main.appVersion=$VER" -o ../module/bin/arm64/taptapapp .)
if [ "$FULL" = "1" ]; then
  cp -f "$SINGBOX_BIN" module/bin/arm64/sing-box
  cp -f "$MIHOMO_BIN" module/bin/arm64/mihomo
  cp -f "$SCRCPY_JAR" module/bin/arm64/scrcpy-server.jar
  # Versi jar bawaan (HARUS sama dengan scrcpyVersion di backend/scrcpy.go):
  # dibaca backend sebagai argumen versi server + "Versi saat ini" scrcpy
  # di kotak Download; layout.sh memindahkannya ke data/bin tiap boot.
  printf '%s\n' "5.0.1" > module/bin/arm64/scrcpy-server.version
fi
chmod 755 module/bin/arm64/*

echo "== webui =="
rm -rf module/webui
cp -r webui module/webui
if [ "$FULL" = "1" ]; then
  echo "== webui: +zashboard bawaan (hanya FULL) =="
  mkdir -p module/webui/zashboard
  cp -r "$ZASHBOARD_DIR"/* module/webui/zashboard/
else
  echo "== slim: tanpa zashboard bawaan (unduh lewat Tentang) =="
fi
echo "$VER" > module/webui/VERSION

if [ "$FULL" = "1" ]; then
  echo "== geodata (satu set bersama) =="
  rm -rf module/geodata && mkdir -p module/geodata
  cp -f "$GEODATA_DIR/geoip.dat" "$GEODATA_DIR/geosite.dat" module/geodata/
else
  echo "== slim: tanpa core/geodata/jar bawaan (unduh lewat Tentang) =="
  rm -rf module/geodata
fi

echo "== paket zip =="
mkdir -p dist
rm -f "dist/taptapapp-go-$VER.zip"
(cd module && zip -r -9 "../dist/taptapapp-go-$VER.zip" . -x '*.DS_Store')
ls -la "dist/taptapapp-go-$VER.zip"

echo "== source zip (slim: tanpa zashboard, geodata, biner) =="
rm -f "dist/taptapapp-go-$VER-source.zip"
rm -rf /tmp/tapp-src && mkdir -p /tmp/tapp-src/taptapapp-go-src
cp -r backend build.sh /tmp/tapp-src/taptapapp-go-src/
# buang artefak build yang mungkin tertinggal di folder backend
rm -f /tmp/tapp-src/taptapapp-go-src/backend/taptapapp /tmp/tapp-src/taptapapp-go-src/backend/taptapclash
mkdir -p /tmp/tapp-src/taptapapp-go-src/module
cp -r module/META-INF module/*.sh module/module.prop /tmp/tapp-src/taptapapp-go-src/module/
mkdir -p /tmp/tapp-src/taptapapp-go-src/webui/icons /tmp/tapp-src/taptapapp-go-src/webui/animasi
cp webui/index.html webui/style.css webui/app.js webui/manifest.json webui/sw.js webui/login.html /tmp/tapp-src/taptapapp-go-src/webui/
cp webui/icons/*.png /tmp/tapp-src/taptapapp-go-src/webui/icons/
cp webui/animasi/*.html /tmp/tapp-src/taptapapp-go-src/webui/animasi/
cp ../MERGE-NOTES.md /tmp/tapp-src/taptapapp-go-src/ 2>/dev/null || true
(cd /tmp/tapp-src && zip -r -9 "$OLDPWD/dist/taptapapp-go-$VER-source.zip" taptapapp-go-src -x '*.DS_Store')
ls -la "dist/taptapapp-go-$VER-source.zip"
echo "SELESAI"
