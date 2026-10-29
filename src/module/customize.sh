# Magisk module installer for taptapapp (gaya modern: Magisk 20.4+ / KernelSU / APatch).
# customize.sh di-source oleh installer, jadi kode ditulis langsung di level
# atas (callback lama print_modname/on_install/set_permissions TIDAK dipanggil).

# Modul ini tidak menimpa file /system apa pun -> tidak perlu magic mount.
SKIPMOUNT=true
PROPFILE=false
POSTFSDATA=false
LATESTARTSERVICE=true

ui_print "****************************************"
ui_print "  TaptapApp-Go: sing-box + mihomo + WebUI"
ui_print "****************************************"

_VER=$(grep -E '^version=' "$MODPATH/module.prop" 2>/dev/null | cut -d= -f2)
[ -z "$_VER" ] && _VER="(versi?)"
ui_print "- Versi  : $_VER"
ui_print "- MODPATH: $MODPATH"

# Binary tersedia untuk arm64 dan armeabi-v7a (32-bit): gagal di awal,
# jangan diam-diam. (ARCH diisi oleh installer; bila kosong, layout.sh
# tetap memeriksa saat boot. Zip arm64 dan v7a dipisah — salah pilih
# ditolak di sini, tidak merusak data.)
case "$ARCH" in
  ""|arm64|arm|armeabi-v7a) ;;
  *) abort "! Arsitektur $ARCH tidak didukung (butuh arm64 atau armeabi-v7a)" ;;
esac

# Salah pilih zip ditolak jelas di awal (bukan diam-diam gagal layout):
# zip arm64 harus membawa bin/arm64, zip v7a harus membawa bin/armv7.
# Bila ARCH kosong (sebagian manager), pemeriksaan ini dilewati dan
# layout.sh tetap menggagalkan instalasi bila biner tidak ketemu.
if [ -n "$MODPATH" ]; then
  case "$ARCH" in
    arm64) [ -f "$MODPATH/bin/arm64/taptapapp" ] || abort "! Zip ini bukan arm64 — pakai zip arm64 untuk HP ini" ;;
    arm|armeabi-v7a) [ -f "$MODPATH/bin/armv7/taptapapp" ] || abort "! Zip ini bukan v7a — pakai zip v7a untuk HP 32-bit ini" ;;
  esac
fi

# Logika tata-letak bersama (juga dijalankan tiap boot oleh service.sh,
# karena sebagian root manager hanya mengekstrak file).
. "$MODPATH/layout.sh"
ui_print "- Menata /data/adb/taptapapp-go/{bin,webui,log,config,geodata} ..."
if ensure_layout "$MODPATH"; then
  ui_print "- Data-dir layout OK"
else
  abort "! Data-dir layout tidak lengkap — lihat pesan di atas"
fi

# Verifikasi akhir: gagal = abort berisik, jangan pernah diam-diam.
# Yang WAJIB hanya backend + WebUI. Core (mihomo/sing-box) sejak modul
# slim (v1.0.32) TIDAK dibundel — boleh belum ada; itu bukan kegagalan
# instalasi, hanya peringatan + arahan unduh (dulu verifikasi ini
# mewajibkan core sehingga flash slim v1.0.33 gagal total di instalasi
# segar: "Verifikasi gagal, hilang: mihomo sing-box"). Zashboard sejak
# v1.0.39 juga TIDAK dibundel di slim (diunduh lewat kotak Download) —
# jangan ulangi kesalahan v1.0.33 dengan mewajibkannya di sini.
_MISS=""
[ -x /data/adb/taptapapp-go/bin/taptapapp ] || _MISS="$_MISS taptapapp"
[ -f /data/adb/taptapapp-go/webui/index.html ] || _MISS="$_MISS webui"
if [ -n "$_MISS" ]; then
  abort "! Verifikasi gagal, hilang:$_MISS"
fi
ui_print "- Verifikasi OK: backend + WebUI"
_OPT_MISS=""
[ -x /data/adb/taptapapp-go/bin/mihomo ] || _OPT_MISS="$_OPT_MISS mihomo"
[ -x /data/adb/taptapapp-go/bin/sing-box ] || _OPT_MISS="$_OPT_MISS sing-box"
if [ -n "$_OPT_MISS" ]; then
  ui_print "! Core belum terpasang:$_OPT_MISS — unduh dulu lewat Tentang → Download (setelah reboot; bisa lewat VPN/WiFi)."
else
  ui_print "- Core OK: mihomo + sing-box"
fi
if [ ! -f /data/adb/taptapapp-go/webui/zashboard/index.html ] && [ ! -f /data/adb/taptapapp-go/zashboard/index.html ]; then
  ui_print "! Zashboard belum terpasang — unduh dulu lewat Tentang → Download (setelah reboot; bisa lewat VPN/WiFi)."
fi

# Port WebUI aktual (bisa diubah user di Pengaturan; default 5656).
_PORT=$(grep -o '"web_port": *[0-9]*' "/data/adb/taptapapp-go/config/settings.json" 2>/dev/null | grep -o '[0-9]*$')
[ -z "$_PORT" ] && _PORT=5656
ui_print ""
ui_print "  WebUI : http://127.0.0.1:$_PORT  (setelah reboot)"
ui_print "  - Dari HP lain (LAN/hotspot) WebUI minta password:"
ui_print "    user 'admin', password lihat Pengaturan WebUI."
ui_print ""

# Izin file: service.sh / uninstall.sh dijalankan lewat 'sh', tapi tetap 0755.
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
# File data-dir ada di luar $MODPATH -> set izin langsung (installer jalan sebagai root).
[ -f /data/adb/taptapapp-go/bin/taptapapp ] && chmod 755 /data/adb/taptapapp-go/bin/taptapapp
[ -f /data/adb/taptapapp-go/bin/mihomo ] && chmod 755 /data/adb/taptapapp-go/bin/mihomo
[ -f /data/adb/taptapapp-go/bin/sing-box ] && chmod 755 /data/adb/taptapapp-go/bin/sing-box
[ -d /data/adb/taptapapp-go/webui ] && chmod -R a+rX /data/adb/taptapapp-go/webui
