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
# Token anti-cache per-build (2026-10-27, diubah 2026-10-27: SW kini
# network-only, jadi token di sw.js bukan lagi nama cache melainkan
# marker versi SW_VERSION): fitur yang dihapus kadang "nyangkut"
# karena sw.js dan app.js?v= tidak pernah berubah di semua build,
# jadi Chrome mengira tidak ada update. Token = hash isi file WebUI
# (berubah tiap ada tambah/hapus/ubah fitur, sama bila isi sama) —
# disisipkan HANYA ke salinan paket (module/webui), bukan ke source,
# supaya build dari source zip di GitHub pun menghasilkan tokennya
# sendiri. Bersama header no-store di backend, WebUI selalu segar
# tiap flash tanpa hapus data situs, dan SW baru tiap build memicu
# activate yang menghapus sisa cache taptapapp-* dari SW lama.
if command -v sha256sum >/dev/null 2>&1; then
  WEBUI_TOKEN=$(cat webui/app.js webui/style.css webui/index.html webui/sw.js | sha256sum | cut -c1-12)
  sed -i "s/taptapapp-v1/taptapapp-$WEBUI_TOKEN/" module/webui/sw.js
  sed -i "s|app.js?v=1.0.0|app.js?v=$WEBUI_TOKEN|" module/webui/index.html
  echo "webui token: $WEBUI_TOKEN"
else
  echo "sha256sum tidak ada — token WebUI dilewati (no-store backend tetap berlaku)"
fi
if [ "$FULL" = "1" ]; then
  echo "== webui: +zashboard bawaan (hanya FULL) =="
  mkdir -p module/webui/zashboard
  cp -r "$ZASHBOARD_DIR"/* module/webui/zashboard/
else
  echo "== slim: tanpa zashboard bawaan (unduh lewat Tentang) =="
fi
echo "$VER" > module/webui/VERSION

# Minify WebUI (JS/CSS/HTML inline) agar modul lebih ringan; perilaku tidak berubah.
# Opsional: butuh node+npm. Bila esbuild tak bisa dipasang (mis. offline), langkah
# ini dilewati dan WebUI tetap dipakai apa adanya. MINIFY=0 untuk mematikan.
if [ "${MINIFY:-1}" = "1" ] && command -v node >/dev/null 2>&1 && [ -f minify-webui.cjs ]; then
  echo "== webui: minify =="
  if [ ! -d node_modules/esbuild ] && command -v npm >/dev/null 2>&1; then
    npm install --no-save --no-audit --no-fund --loglevel=error esbuild@0.27.7 >/dev/null 2>&1 || true
  fi
  node minify-webui.cjs module/webui || echo "minify dilewati (gagal), WebUI dipakai apa adanya"
fi

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
cp minify-webui.cjs /tmp/tapp-src/taptapapp-go-src/ 2>/dev/null || true
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
