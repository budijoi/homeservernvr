
# My Home Server 🖥️

**Self-Hosted di STB Bekas — All-in-One Home Server**

Proyek ini mengubah **STB B860H (S905X)** dengan **eMMC rusak** menjadi server rumahan serbaguna yang berjalan sepenuhnya dari **SD Card**. Cocok untuk belajar self-hosting, monitoring rumah, atau sekadar eksperimen server murah.

---

## 📋 Spesifikasi Perangkat

| Komponen | Detail |
|----------|--------|
| **Device** | STB B860H v1 |
| **SoC** | Amlogic S905X (ARM Cortex-A53) |
| **RAM** | 1 GB DDR3 |
| **Storage** | SD Card (eMMC rusak/tidak dipakai) |
| **Koneksi** | LAN + Wi-Fi |
| **OS** | Armbian (Linux 6.x) |

---

## ✨ Fitur

| # | Fitur | Port | Keterangan |
|---|-------|------|------------|
| 1 | **Dashboard Monitor** | `:8080` | CPU%, temperatur, RAM, ZRAM, SWAP, SDCARD, RX/TX real-time |
| 2 | **Blog Static** | `/blog` | Halaman dokumentasi dan catatan |
| 3 | **FileBrowser** | `:8081` | Manajemen file via web — folder: Document, Music, Pictures, Videos |
| 4 | **CCTV NVR** | `:8765` | motionEye — rekaman kamera IP 24 jam |
| 5 | **Cloudflare Tunnel** | — | Akses server dari luar tanpa IP publik |
| 6 | **TTYD + BTOP** | `:7681` | Terminal monitoring via web browser |

### Optimasi Sistem
- ZRAM **512 MB** — kompresi memori untuk RAM 1 GB
- SWAP file **2 GB** di SD Card
- Swappiness **10** — prioritaskan ZRAM
- I/O scheduler **cfq** + read-ahead **256 KB** untuk SD Card
- Kernel tuning — BBR congestion control, network buffer optimal

---

## 📦 Instalasi

### Persyaratan
- STB B860H sudah terpasang **Armbian** (boot dari SD Card)
- Koneksi internet
- Akun **Cloudflare** (opsional, untuk tunnel)

### Langkah Instalasi

**1. Clone repositori ini di STB:**

```bash
git clone https://github.com/username/my-home-server.git
cd my-home-server
```

Atau copy folder `homeserver/` via SCP/USB.

**2. Jalankan installer sebagai root:**

```bash
sudo bash install.sh
```

**3. Ikuti panduan interaktif:**

Installer akan menampilkan setiap langkah dengan jelas:
- ✅ Konfigurasi ZRAM dan SWAP
- ✅ Optimasi kernel untuk S905X
- ✅ Instalasi Dashboard + Blog
- ✅ Instalasi FileBrowser + folder penyimpanan
- ✅ Instalasi motionEye NVR + kamera
- 🔷 Cloudflare Tunnel (input domain jika ingin)

> **Waktu instalasi:** ~20–30 menit (tergantung kecepatan SD Card dan koneksi internet)

**4. Reboot setelah selesai:**

```bash
sudo reboot
```

---

## 🚀 Akses Layanan

Setelah instalasi, akses dari browser di jaringan yang sama:

| Layanan | URL | Login |
|---------|-----|-------|
| **Dashboard** | `http://IP_STB:8080` | — |
| **Blog** | `http://IP_STB:8080/blog` | — |
| **FileBrowser** | `http://IP_STB:8081` | `admin` / `moch1234` |
| **NVR CCTV** | `http://IP_STB:8765` | `admin` / `moch1234` |
| **Terminal** | `http://IP_STB:7681` | `admin` / `moch1234` |

Ganti `IP_STB` dengan alamat IP perangkat (cek via `hostname -I`).

### Jika menggunakan Cloudflare Tunnel:
```
https://dashboard.domain-anda.com
https://files.domain-anda.com
https://nvr.domain-anda.com
https://status.domain-anda.com
```

---

## 📁 Struktur Penyimpanan

```
/storage/
├── My Document/          # Dokumen pribadi
├── My Music/             # Koleksi musik
├── My Pictures/          # Foto dan gambar
└── My Videos/
    └── NVR/              # Rekaman CCTV (otomatis)
```

---

## ⚙️ Manajemen Service

```bash
# Cek status semua service
systemctl status homeserver-dashboard
systemctl status filebrowser
systemctl status motioneye
systemctl status cloudflared
systemctl status ttyd

# Restart service tertentu
systemctl restart homeserver-dashboard

# Lihat log real-time
journalctl -u homeserver-dashboard -f
```

---

## 🛠️ Kustomisasi

### Ganti password FileBrowser
```bash
filebrowser users update admin --password=newpassword -d /opt/filebrowser/filebrowser.db
```

### Tambah kamera NVR
Edit file konfigurasi kamera:
```bash
nano /etc/motioneye/camera-1.conf
```
Restart motionEye setelah perubahan:
```bash
systemctl restart motioneye
```

### Ubah port dashboard
Edit file service:
```bash
nano /etc/systemd/system/homeserver-dashboard.service
# Ubah port 8080 di baris ExecStart
systemctl daemon-reload
systemctl restart homeserver-dashboard
```

---

## ❤️ Donasi

Proyek ini dikembangkan secara sukarela. Jika bermanfaat, dukungan Anda sangat berarti:

| Metode | Detail |
|--------|--------|
| **DANA** | `085323073037` (a.n. Moh Agus Budiman) |
| **Mandiri** | `1310014031126` (a.n. Moh Agus Budiman) |
| **BNI** | `2027537451` (a.n. Moh Agus Budiman) |
| **QRIS** | Scan via DANA |
| **Konfirmasi** | [WhatsApp Admin](https://wa.me/6288224553181?text=Halo%20kak%2C%20saya%20mau%20konfirmasi%20donasi%20untuk%20My%20Home%20Server) |

Tombol donasi juga tersedia di halaman Dashboard.

---

## 📜 Lisensi

Proyek ini dirilis untuk penggunaan pribadi dan pembelajaran. Gunakan dengan bijak.

---

## 🙏 Credit

- [Armbian](https://www.armbian.com/) — OS ringan untuk ARM
- [Flask](https://flask.palletsprojects.com/) — Web framework Python
- [FileBrowser](https://filebrowser.org/) — Manajemen file via web
- [motionEye](https://github.com/motioneye-project/motioneye) — NVR CCTV
- [Cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/) — Tunnel
- [TTYD](https://github.com/tsl0922/ttyd) — Terminal via web
- [BTOP](https://github.com/aristocratos/btop) — Resource monitor
