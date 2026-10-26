#!/system/bin/sh
# taptapapp Magisk service: starts the Go backend at boot.
MODDIR=${0%/*}
DATA=/data/adb/taptapapp-go
LOG=$DATA/log/backend.log

export PATH=/system/bin:/system/xbin:/vendor/bin:$PATH
mkdir -p "$DATA" "$DATA/log"

# The module installer (customize.sh) is NOT executed by every root
# manager — e.g. KernelSU-Next's "overlayfsx metainstall" only extracts
# files and never calls on_install. So the data-dir layout is enforced
# here as well: idempotent, runs at every boot.
if [ -f "$MODDIR/layout.sh" ]; then
  . "$MODDIR/layout.sh"
  ensure_layout "$MODDIR" >> "$LOG" 2>&1 \
    || echo "WARNING: data-dir layout incomplete (see above)" >> "$LOG"
fi

if [ ! -f "$DATA/webui/index.html" ]; then
  echo "WARNING: $DATA/webui/index.html not found — WebUI disabled, API only" >> "$LOG"
fi

# wait for boot to complete
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
  sleep 2
done
sleep 5

# kill leftovers from previous boot (if any)
# NOTE: full-path pattern avoids matching this script's own path
# (.../taptapapp/service.sh), which a plain "taptapapp" pattern would kill.
pkill -f "/data/adb/taptapapp-go/bin/taptapapp" 2>/dev/null
pkill -f "/data/adb/taptapapp-go/bin/mihomo" 2>/dev/null
pkill -f "/data/adb/taptapapp-go/bin/sing-box" 2>/dev/null
# bpf2socks sisa versi lama (eBPF sudah dihapus): matikan bila masih ada.
pkill -9 -f "bpf2socks" 2>/dev/null
sleep 1

if [ ! -x "$DATA/bin/taptapapp" ]; then
  echo "ERROR: $DATA/bin/taptapapp not found — backend cannot start" >> "$LOG"
  exit 1
fi

echo "--- $(date) : starting taptapapp ---" >> "$LOG"
"$DATA/bin/taptapapp" -datadir "$DATA" >> "$LOG" 2>&1 &
