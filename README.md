# TaptapApp-Go

Modul Magisk: transparent proxy dua core (sing-box + mihomo, bisa dipilih)
dengan satu daemon Go dan satu WebUI. Buka WebUI setelah instalasi:
http://127.0.0.1:5656

Source ini adalah basis **v1.0.51** internal yang penomorannya direset
penuh ke awal untuk jalur build GitHub: **v1.0.0**, versionCode 1, cache
service worker v1. Isi WebUI dan backend sama persis dengan v1.0.51;
yang berubah hanya nomornya, fungsinya tetap.

## Paket SLIM

Zip hasil build adalah paket SLIM: core (sing-box, mihomo), geodata,
zashboard, dan scrcpy-server **tidak dibundel**. Sesudah flash, unduh
semuanya lewat kotak Download di menu Tentang WebUI, urutannya: Core
mihomo, Core sing-box, Geodata, Zashboard, Scrcpy. Tanpa itu modul jalan
tapi tidak ada core yang bisa di-start.

## Build di GitHub Actions

1. Unggah isi repo ini ke repo GitHub baru (branch `main`).
2. Buka tab **Actions** → workflow **Build TaptapApp-Go** → **Run
   workflow**.
3. Unduh artifact `taptapapp-go-v1.0.0` dari halaman run yang sukses.
   Isinya hanya zip instalasi (siap flash); zip source tidak ikut
   diunggah, supaya artifact langsung bisa dipasang.

Tidak ada GitHub Releases: unduhan hanya lewat artifact Actions.

## Build lokal (opsional)

Butuh Go 1.21+ (terverifikasi dengan Go 1.27). Dari folder `src/`:

```sh
sh build.sh
```

Hasilnya ada di `src/dist/`: `taptapapp-go-v1.0.0.zip` (instalasi) dan
`taptapapp-go-v1.0.0-source.zip` (source slim). Build lokal tidak butuh
aset eksternal selama paket SLIM (default); `FULL=1` membundel semua aset
dan butuh folder `assets/` (core, geodata, zashboard, scrcpy-server.jar).

## WebUI diperingan

`src/build.sh` memperkecil WebUI saat build (`src/minify-webui.cjs`, esbuild:
JS, CSS, dan blok inline di HTML, termasuk file animasi). Perilaku dan tampilan
tidak berubah; source di `src/webui/` tetap terbaca dan itulah yang diedit.
Butuh node+npm (sudah ada di GitHub Actions); bila tidak ada, langkah ini
dilewati otomatis. `MINIFY=0 sh build.sh` untuk mematikannya.

## Versi

Satu sumber kebenaran: `src/module/module.prop` (`version` dan
`versionCode`). Backend mengambil versi dari sana saat build
(`-ldflags -X main.appVersion=...`), jadi Tentang selalu menampilkan
versi yang sama dengan module.prop. Penomoran dimulai dari nol:
v1.0.0 → versionCode 1, v1.0.1 → 2, dan seterusnya.

Catatan: karena penomoran direset ke awal, versionCode 1 jauh lebih
kecil dari v1.0.51 internal (151). Magisk tidak akan menawarkannya
sebagai "update" atas v1.0.51 yang sudah terpasang; pasang manual lewat
"Install dari penyimpanan" bila ingin pindah ke jalur 1.0.0 ini.

## Komponen pihak ketiga

- sing-box — https://github.com/SagerNet/sing-box
- mihomo — https://github.com/MetaCubeX/mihomo
- geodata (geoip.dat, geosite.dat) — https://github.com/MetaCubeX/meta-rules-dat
- zashboard — https://github.com/Zephyruso/zashboard
- scrcpy server — https://github.com/Genymobile/scrcpy

Semuanya diunduh terpisah lewat kotak Download sesudah instalasi,
bukan dibundel di zip ini.
