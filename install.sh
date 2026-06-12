#!/bin/bash
# ============================================================
#  MY HOME SERVER v1.0
#  All-in-One Installer untuk STB B860H (S905X)
#  Armbian + SDCARD
#
#  Fitur:
#  - Dashboard Monitor (CPU, RAM, ZRAM, SWAP, SDCARD, Network)
#  - Blog Static
#  - FileBrowser dengan folder terstruktur
#  - CCTV NVR (motionEye)
#  - Cloudflare Tunnel
#  - ZRAM 512MB + SWAP 2GB + Optimasi S905X
# ============================================================

VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOMESERVER_DIR="/opt/homeserver"
DASHBOARD_DIR="$HOMESERVER_DIR/dashboard"
BLOG_DIR="$HOMESERVER_DIR/blog"
FILEBROWSER_DIR="/opt/filebrowser"
CLOUDFLARED_DIR="/root/.cloudflared"
SWAP_FILE="/swapfile"
ZRAM_SIZE="512M"
SWAP_SIZE="2048"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

clear

# ============================================================
# FUNCTIONS
# ============================================================

print_banner() {
  echo ""
  echo -e "${CYAN}  ╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}  ║${WHITE}          MY HOME SERVER v${VERSION}           ${CYAN}║${NC}"
  echo -e "${CYAN}  ║${NC}  ${YELLOW}Self-Hosted di STB Bekas${NC}               ${CYAN}║${NC}"
  echo -e "${CYAN}  ║${NC}  ${YELLOW}B860H | S905X | Armbian${NC}              ${CYAN}║${NC}"
  echo -e "${CYAN}  ╚══════════════════════════════════════════════╝${NC}"
  echo ""
}

section() {
  local num=$1
  local title=$2
  echo ""
  echo -e "${BLUE}  ════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  [${WHITE}${num}${BLUE}]${WHITE} ${title}${NC}"
  echo -e "${BLUE}  ════════════════════════════════════════════════${NC}"
  echo ""
}

info()  { echo -e "${CYAN}  [INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}  [ ✓ ]${NC}  $1"; }
warn()  { echo -e "${YELLOW}  [!]${NC}  $1"; }
err()   { echo -e "${RED}  [✗]${NC}  $1"; }
step()  { echo -e "${MAGENTA}  -->${NC}  $1"; }

spinner() {
  local pid=$1
  local delay=0.1
  local spin='|/-\'
  while ps -p $pid > /dev/null 2>&1; do
    for i in $(seq 0 3); do
      echo -ne "\r  [${spin:$i:1}] $2"
      sleep $delay
    done
  done
  echo -ne "\r  [${GREEN}✓${NC}] $2\n"
}

confirm() {
  echo ""
  echo -e -n "${YELLOW}  [?]${NC} $1 [y/N]: "
  read -r resp
  [[ "$resp" =~ ^[Yy]([Ee][Ss])?$ ]]
}

wait_enter() {
  echo ""
  echo -e "${YELLOW}  [?]${NC} Tekan Enter untuk melanjutkan..."
  read -r
}

check_root() {
  if [[ $EUID -ne 0 ]]; then
    err "Script harus dijalankan sebagai root!"
    echo "  Jalankan: sudo bash install.sh"
    exit 1
  fi
  ok "Root privileges terdeteksi"
}

check_arch() {
  local arch=$(uname -m)
  if [[ "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
    warn "Arsitektur: $arch (bukan ARM64)"
    warn "Script ini dioptimalkan untuk S905X (ARM64)"
    if ! confirm "Lanjutkan instalasi?"; then
      exit 1
    fi
  else
    ok "Arsitektur: $arch"
  fi
}

check_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    ok "Sistem: $NAME $VERSION_ID"
  else
    warn "Tidak dapat mendeteksi OS"
  fi
}

get_active_iface() {
  for iface in /sys/class/net/*; do
    name=$(basename "$iface")
    [ "$name" = "lo" ] && continue
    if [[ "$(cat "$iface"/operstate 2>/dev/null)" == "up" ]]; then
      echo "$name"
      return
    fi
  done
  echo "eth0"
}

# ============================================================
# MAIN INSTALLATION
# ============================================================

main() {
  print_banner

  echo -e "  ${WHITE}Script ini akan menginstal dan mengkonfigurasi:${NC}"
  echo ""
  echo -e "  ${GREEN}1.${NC} Dashboard Monitor (Port 8080)"
  echo -e "  ${GREEN}2.${NC} Blog Static (via Dashboard)"
  echo -e "  ${GREEN}3.${NC} FileBrowser (Port 8081)"
  echo -e "  ${GREEN}4.${NC} CCTV NVR - motionEye (Port 8765)"
  echo -e "  ${GREEN}5.${NC} Cloudflare Tunnel"
  echo -e "  ${GREEN}6.${NC} TTYD + BTOP (Port 7681)"
  echo -e "  ${GREEN}7.${NC} ZRAM 512MB + SWAP 2GB"
  echo -e "  ${GREEN}8.${NC} Optimasi Sistem untuk S905X"
  echo ""
  echo -e "  ${YELLOW}Perkiraan waktu: 20-30 menit (tergantung koneksi)${NC}"
  echo ""

  if ! confirm "Mulai instalasi My Home Server?"; then
    echo ""
    info "Instalasi dibatalkan."
    exit 0
  fi

  # ===================== SECTION 0 =====================
  section "0" "PERSIAPAN"
  check_root
  check_arch
  check_os

  echo ""
  info "Memperbarui paket sistem..."
  apt-get update -qq 2>/dev/null &
  spinner $! "Memperbarui daftar paket"
  ok "Daftar paket diperbarui"

  # ===================== SECTION 1 =====================
  section "1" "INSTALASI PAKET DASAR"

  info "Menginstal paket yang diperlukan..."
  step "python3, pip, flask, git, curl, wget, ufw, dll"

  apt-get install -y -qq \
    python3 python3-pip python3-venv \
    curl wget git ufw \
    htop iotop btop \
    nload nmap net-tools \
    lm-sensors \
    motion \
    build-essential \
    pkg-config libglib2.0-dev \
    ttyd \
    2>/dev/null &
  spinner $! "Menginstal paket dasar"
  ok "Paket dasar terinstal"

  info "Menginstal pustaka Python..."
  pip3 install flask 2>/dev/null &
  spinner $! "Menginstal Flask"
  ok "Flask terinstal"

  # ===================== SECTION 2 =====================
  section "2" "KONFIGURASI ZRAM (512MB)"

  info "Mengkonfigurasi ZRAM 512MB..."
  step "Memeriksa modul zram"

  if lsmod | grep -q zram; then
    ok "Modul zram sudah aktif"
  else
    modprobe zram 2>/dev/null
    if lsmod | grep -q zram; then
      ok "Modul zram diaktifkan"
    else
      err "Modul zram tidak tersedia"
      warn "Lanjutkan tanpa ZRAM..."
    fi
  fi

  if lsmod | grep -q zram; then
    step "Membuat ZRAM device..."
    echo "$ZRAM_SIZE" > /sys/block/zram0/disksize 2>/dev/null
    mkswap /dev/zram0 2>/dev/null
    swapon -p 100 /dev/zram0 2>/dev/null
    ok "ZRAM 512MB aktif dengan prioritas tinggi"

    # Create ZRAM service
    cat > /etc/systemd/system/zram-config.service << 'ZRAMEOF'
[Unit]
Description=ZRAM Configuration for My Home Server
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "echo 512M > /sys/block/zram0/disksize && mkswap /dev/zram0 && swapon -p 100 /dev/zram0"
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
ZRAMEOF

    systemctl daemon-reload 2>/dev/null
    systemctl enable zram-config.service 2>/dev/null
    ok "ZRAM service terdaftar (akan aktif setelah reboot)"
  fi

  # ===================== SECTION 3 =====================
  section "3" "MEMBUAT SWAP FILE (2GB)"

  info "Membuat SWAP file ${SWAP_SIZE}MB..."

  if swapon --show | grep -v zram | grep -q "$SWAP_FILE"; then
    ok "SWAP file sudah ada"
  else
    step "Membuat file ${SWAP_SIZE}MB (mohon tunggu)..."
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SWAP_SIZE" status=progress 2>/dev/null
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE" 2>/dev/null
    swapon "$SWAP_FILE" 2>/dev/null
    ok "SWAP file ${SWAP_SIZE}MB dibuat dan diaktifkan"

    if ! grep -q "$SWAP_FILE" /etc/fstab; then
      echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
      ok "SWAP file ditambahkan ke /etc/fstab"
    fi
  fi

  # ===================== SECTION 4 =====================
  section "4" "OPTIMASI SISTEM UNTUK S905X"

  info "Menerapkan optimasi sistem..."

  step "Mengatur kernel parameters..."
  cat > /etc/sysctl.d/99-homeserver.conf << 'SYSCTLEOF'
# My Home Server - Optimasi untuk S905X + SDCARD
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.min_free_kbytes=16384
vm.page-cluster=0
kernel.nmi_watchdog=0
kernel.sched_autogroup_enabled=1
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
SYSCTLEOF
  sysctl -p /etc/sysctl.d/99-homeserver.conf 2>/dev/null
  ok "Kernel parameters dioptimalkan"

  step "Optimasi I/O Scheduler untuk SDCARD..."
  local mmc_dev
  mmc_dev=$(lsblk -d -o NAME,TRAN 2>/dev/null | grep -i mmc | awk '{print $1}' | head -1)
  if [ -n "$mmc_dev" ]; then
    echo "cfq" > "/sys/block/$mmc_dev/queue/scheduler" 2>/dev/null
    echo "256" > "/sys/block/$mmc_dev/queue/read_ahead_kb" 2>/dev/null
    ok "I/O Scheduler diatur untuk SDCARD ($mmc_dev)"
  fi

  step "Menonaktifkan service yang tidak diperlukan..."
  systemctl disable bluetooth.service 2>/dev/null || true
  systemctl disable hciuart.service 2>/dev/null || true
  systemctl disable apt-daily.timer 2>/dev/null || true
  systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
  ok "Service tidak terpakai dinonaktifkan"

  # ===================== SECTION 5 =====================
  section "5" "DASHBOARD MONITOR + BLOG"

  info "Membuat struktur dashboard dan blog..."

  mkdir -p "$DASHBOARD_DIR/templates"
  mkdir -p "$BLOG_DIR"

  info "Membuat dashboard Flask app..."

  cat > "$DASHBOARD_DIR/app.py" << 'PYEOF'
#!/usr/bin/env python3
import os, time, threading, subprocess
from flask import Flask, jsonify, render_template, send_from_directory

app = Flask(__name__)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

stats = {
    'cpu_percent': 0, 'cpu_temp': 0, 'cpu_freq': 0,
    'ram_total': 0, 'ram_used': 0, 'ram_percent': 0,
    'zram_total': 0, 'zram_used': 0, 'zram_percent': 0,
    'swap_total': 0, 'swap_used': 0, 'swap_percent': 0,
    'disk_total': 0, 'disk_used': 0, 'disk_percent': 0,
    'rx_bytes': 0, 'tx_bytes': 0, 'rx_speed': 0, 'tx_speed': 0,
    'hostname': '', 'ip': '', 'uptime': '',
}

def read_int(path):
    try:
        with open(path) as f:
            return int(f.read().strip())
    except:
        return 0

def read_line(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except:
        return ''

def get_cpu_percent():
    try:
        with open('/proc/stat') as f:
            l1 = [float(x) for x in f.readline().split()[1:]]
        time.sleep(0.5)
        with open('/proc/stat') as f:
            l2 = [float(x) for x in f.readline().split()[1:]]
        total = sum(l2) - sum(l1)
        idle = l2[3] - l1[3]
        return round((1 - idle / total) * 100, 1) if total else 0
    except:
        return 0

def get_cpu_temp():
    for i in range(10):
        t = read_int(f'/sys/class/thermal/thermal_zone{i}/temp')
        if t and t > 0:
            return round(t / 1000, 1)
    return 0

def get_cpu_freq():
    f = read_int('/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq')
    if f:
        return round(f / 1000)
    f = read_int('/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq')
    return round(f / 1000) if f else 0

def get_mem_info():
    mem = {}
    for line in read_line('/proc/meminfo').split('\n'):
        parts = line.split(':')
        if len(parts) == 2:
            key = parts[0].strip()
            try:
                mem[key] = int(parts[1].strip().split()[0])
            except:
                mem[key] = 0
    return mem

def get_disk_usage(path='/'):
    try:
        s = os.statvfs(path)
        total = s.f_frsize * s.f_blocks
        free = s.f_frsize * s.f_bfree
        used = total - free
        percent = round(used / total * 100, 1) if total else 0
        return {'total': total, 'used': used, 'percent': percent}
    except:
        return {'total': 0, 'used': 0, 'percent': 0}

def get_net_bytes(iface):
    try:
        with open('/proc/net/dev') as f:
            for line in f:
                if iface in line and ':' in line:
                    parts = line.split()
                    rx = int(parts[1])
                    tx = int(parts[9])
                    return rx, tx
    except:
        pass
    return 0, 0

def detect_iface():
    try:
        with open('/proc/net/dev') as f:
            for line in f:
                if ':' in line:
                    iface = line.split(':')[0].strip()
                    if iface != 'lo':
                        return iface
    except:
        pass
    return 'eth0'

def get_ip(iface):
    try:
        r = subprocess.run(['ip', '-4', 'addr', 'show', iface], capture_output=True, text=True, timeout=5)
        for line in r.stdout.split('\n'):
            if 'inet ' in line:
                return line.split()[1].split('/')[0]
    except:
        pass
    try:
        r = subprocess.run(['hostname', '-I'], capture_output=True, text=True, timeout=5)
        return r.stdout.strip().split()[0]
    except:
        return 'N/A'

def get_uptime():
    try:
        with open('/proc/uptime') as f:
            seconds = float(f.read().split()[0])
        days = int(seconds // 86400)
        hours = int((seconds % 86400) // 3600)
        minutes = int((seconds % 3600) // 60)
        return f'{days}d {hours}h {minutes}m' if days > 0 else f'{hours}h {minutes}m'
    except:
        return 'N/A'

def monitor():
    global stats
    prev_rx, prev_tx = 0, 0
    prev_time = time.time()
    iface = detect_iface()
    while True:
        cpu_percent = get_cpu_percent()
        cpu_temp = get_cpu_temp()
        cpu_freq = get_cpu_freq()
        mem = get_mem_info()
        ram_total = mem.get('MemTotal', 0)
        ram_avail = mem.get('MemAvailable', 0)
        ram_used = ram_total - ram_avail
        ram_percent = round(ram_used / ram_total * 100, 1) if ram_total else 0
        st = mem.get('SwapTotal', 0)
        zram_total = st
        zram_used = mem.get('SwapCached', 0)
        zram_percent = round(zram_used / zram_total * 100, 1) if zram_total else 0
        sf = mem.get('SwapFree', 0)
        swap_used = st - sf
        swap_percent = round(swap_used / st * 100, 1) if st else 0
        disk = get_disk_usage('/')
        rx, tx = get_net_bytes(iface)
        now = time.time()
        dt = now - prev_time
        rx_speed = (rx - prev_rx) / dt if dt > 0 else 0
        tx_speed = (tx - prev_tx) / dt if dt > 0 else 0
        prev_rx, prev_tx, prev_time = rx, tx, now
        hostname = os.uname().nodename
        ip = get_ip(iface)
        uptime = get_uptime()
        stats.update({
            'cpu_percent': cpu_percent, 'cpu_temp': cpu_temp, 'cpu_freq': cpu_freq,
            'ram_total': ram_total, 'ram_used': ram_used, 'ram_percent': ram_percent,
            'zram_total': zram_total, 'zram_used': zram_used, 'zram_percent': zram_percent,
            'swap_total': st, 'swap_used': swap_used, 'swap_percent': swap_percent,
            'disk_total': disk['total'], 'disk_used': disk['used'], 'disk_percent': disk['percent'],
            'rx_bytes': rx, 'tx_bytes': tx, 'rx_speed': rx_speed, 'tx_speed': tx_speed,
            'hostname': hostname, 'ip': ip, 'uptime': uptime,
        })

def fmt(b):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if b < 1024:
            return f'{b:.1f} {unit}'
        b /= 1024
    return f'{b:.1f} PB'

@app.route('/api/stats')
def api_stats():
    s = stats
    return jsonify({
        'cpu_percent': s['cpu_percent'], 'cpu_temp': s['cpu_temp'], 'cpu_freq': s['cpu_freq'],
        'ram_used': s['ram_used'], 'ram_total': s['ram_total'], 'ram_percent': s['ram_percent'],
        'ram_used_fmt': fmt(s['ram_used']), 'ram_total_fmt': fmt(s['ram_total']),
        'zram_percent': s['zram_percent'],
        'zram_used_fmt': fmt(s['zram_used']), 'zram_total_fmt': fmt(s['zram_total']),
        'swap_percent': s['swap_percent'],
        'swap_used_fmt': fmt(s['swap_used']), 'swap_total_fmt': fmt(s['swap_total']),
        'disk_percent': s['disk_percent'],
        'disk_used_fmt': fmt(s['disk_used']), 'disk_total_fmt': fmt(s['disk_total']),
        'rx_speed': fmt(s['rx_speed']), 'tx_speed': fmt(s['tx_speed']),
        'rx_total_fmt': fmt(s['rx_bytes']), 'tx_total_fmt': fmt(s['tx_bytes']),
        'hostname': s['hostname'], 'ip': s['ip'], 'uptime': s['uptime'],
    })

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/blog')
@app.route('/blog/<path:filename>')
def blog(filename=None):
    blog_dir = os.path.join(os.path.dirname(BASE_DIR), 'blog')
    if filename:
        return send_from_directory(blog_dir, filename)
    return send_from_directory(blog_dir, 'index.html')

if __name__ == '__main__':
    t = threading.Thread(target=monitor, daemon=True)
    t.start()
    time.sleep(1)
    app.run(host='0.0.0.0', port=8080, debug=False, threaded=True)
PYEOF
  ok "Dashboard app.py dibuat"

  info "Membuat template dashboard HTML..."
  cat > "$DASHBOARD_DIR/templates/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>My Home Server - B860H</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{
  font-family:'Segoe UI',system-ui,-apple-system,sans-serif;
  background:#0a0e17;color:#e0e6ed;
  min-height:100vh;padding:20px
}
.container{max-width:1000px;margin:0 auto}
.header{
  text-align:center;padding:25px 20px;
  background:linear-gradient(135deg,#131a2b,#1a2340);
  border-radius:16px;margin-bottom:24px;border:1px solid #1e2a45
}
.header h1{
  font-size:1.6em;
  background:linear-gradient(135deg,#00d4ff,#00ff88);
  -webkit-background-clip:text;-webkit-text-fill-color:transparent;
  background-clip:text
}
.header .sub{color:#8892a4;font-size:.85em;margin-top:6px}
.header .sub span{margin:0 12px;color:#3a4560}
.stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:14px;margin-bottom:20px}
.card{
  background:linear-gradient(145deg,#131a2b,#0f1625);
  border-radius:14px;padding:18px;text-align:center;
  border:1px solid #1e2a45;transition:transform .2s,box-shadow .2s
}
.card:hover{transform:translateY(-2px);box-shadow:0 8px 24px rgba(0,212,255,.08)}
.card .label{
  font-size:.75em;text-transform:uppercase;letter-spacing:1px;
  color:#5a6a8a;margin-bottom:10px
}
.card .circle{
  width:90px;height:90px;border-radius:50%;
  margin:0 auto 10px;position:relative;
  display:flex;align-items:center;justify-content:center;flex-direction:column
}
.card .circle svg{position:absolute;width:90px;height:90px;transform:rotate(-90deg)}
.card .circle svg circle{fill:none;stroke-width:5;cx:45;cy:45;r:38}
.card .circle .bg{stroke:#1e2a45}
.card .circle .fg{stroke-linecap:round;transition:stroke-dashoffset .6s ease}
.card .circle .value{font-size:1.2em;font-weight:700;z-index:1}
.card .circle .sub-value{font-size:.6em;color:#8892a4;z-index:1}
.card .detail{font-size:.78em;color:#8892a4;line-height:1.6}
.card .detail strong{color:#c0c8d6}
.network-card{
  background:linear-gradient(145deg,#131a2b,#0f1625);
  border-radius:14px;padding:20px 24px;border:1px solid #1e2a45;margin-bottom:20px
}
.network-card .label{
  font-size:.75em;text-transform:uppercase;letter-spacing:1px;
  color:#5a6a8a;margin-bottom:14px
}
.network-card .bar-group{margin-bottom:10px}
.network-card .bar-group .bar-label{
  display:flex;justify-content:space-between;font-size:.82em;margin-bottom:4px
}
.network-card .bar-group .bar-label .tag{color:#8892a4;min-width:28px}
.network-card .bar-group .bar-label .speed{color:#c0c8d6;font-weight:600}
.network-card .bar-track{height:8px;background:#1e2a45;border-radius:4px;overflow:hidden}
.network-card .bar-fill{height:100%;border-radius:4px;transition:width .8s ease;width:0%}
.network-card .bar-fill.rx{background:linear-gradient(90deg,#00d4ff,#0090ff)}
.network-card .bar-fill.tx{background:linear-gradient(90deg,#00ff88,#00cc6a)}
.network-card .total-row{
  display:flex;justify-content:space-between;font-size:.78em;
  color:#5a6a8a;margin-top:8px;padding-top:10px;border-top:1px solid #1e2a45
}
.nav-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:12px}
.nav-btn{
  display:flex;flex-direction:column;align-items:center;justify-content:center;
  padding:18px 12px;background:linear-gradient(145deg,#131a2b,#0f1625);
  border-radius:14px;border:1px solid #1e2a45;text-decoration:none;
  color:#c0c8d6;font-size:.82em;transition:all .25s;cursor:pointer
}
.nav-btn:hover{border-color:#00d4ff;transform:translateY(-2px);box-shadow:0 8px 24px rgba(0,212,255,.1);color:#fff}
.nav-btn .icon{font-size:2em;margin-bottom:6px}
.nav-btn.blog .icon{color:#ff6b6b}
.nav-btn.files .icon{color:#ffd93d}
.nav-btn.nvr .icon{color:#6bcbff}
.nav-btn.status .icon{color:#00ff88}
.nav-btn.donate .icon{color:#ff6b9d}
.modal-overlay{
  display:none;position:fixed;top:0;left:0;right:0;bottom:0;
  background:rgba(0,0,0,.7);backdrop-filter:blur(4px);
  z-index:1000;align-items:center;justify-content:center
}
.modal-overlay.active{display:flex}
.modal{
  background:#131a2b;border-radius:16px;padding:30px;
  max-width:400px;width:90%;border:1px solid #1e2a45;position:relative
}
.modal .close{
  position:absolute;top:12px;right:16px;
  background:none;border:none;color:#5a6a8a;
  font-size:1.4em;cursor:pointer;transition:color .2s
}
.modal .close:hover{color:#fff}
.modal h2{text-align:center;margin-bottom:20px;font-size:1.2em;color:#ff6b9d}
.modal .payment{
  background:#0f1625;border-radius:10px;padding:14px;margin-bottom:10px;font-size:.88em
}
.modal .payment .bank{color:#00d4ff;font-weight:600}
.modal .payment .number{
  font-family:'Courier New',monospace;font-size:1.1em;color:#fff;margin-top:4px
}
.modal .qris{text-align:center;margin:16px 0}
.modal .qris img{max-width:200px;border-radius:10px;border:1px solid #1e2a45}
.modal .whatsapp-btn{
  display:block;text-align:center;background:#25d366;color:#fff;
  padding:12px;border-radius:10px;text-decoration:none;font-weight:600;margin-top:14px
}
.modal .whatsapp-btn:hover{opacity:.85}
.modal .note{text-align:center;font-size:.78em;color:#5a6a8a;margin-top:12px}
@media(max-width:600px){
  body{padding:12px}
  .stats-grid{grid-template-columns:repeat(2,1fr);gap:10px}
  .card{padding:14px}
  .card .circle{width:70px;height:70px}
  .card .circle svg{width:70px;height:70px}
  .card .circle svg circle{cx:35;cy:35;r:30}
  .card .circle .value{font-size:1em}
  .nav-grid{grid-template-columns:repeat(3,1fr)}
}
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>My Home Server</h1>
<div class="sub"><span>B860H</span> &bull; <span>S905X</span> &bull; <span>1GB RAM</span> &bull; <span>Armbian</span></div>
<div class="sub" style="margin-top:8px;font-size:.82em">
<span id="hostname">-</span> &bull; IP: <span id="ip">-</span> &bull; Up: <span id="uptime">-</span>
</div>
</div>

<div class="stats-grid">
<div class="card">
<div class="label">CPU</div>
<div class="circle">
<svg viewBox="0 0 90 90"><circle class="bg" cx="45" cy="45" r="38"/><circle class="fg cpu-fg" cx="45" cy="45" r="38" stroke="#00d4ff" stroke-dasharray="238.76" stroke-dashoffset="238.76"/></svg>
<div class="value" id="cpu-val">0%</div>
<div class="sub-value" id="cpu-temp">-</div>
</div>
<div class="detail"><span id="cpu-freq">-</span> MHz</div>
</div>
<div class="card">
<div class="label">RAM</div>
<div class="circle">
<svg viewBox="0 0 90 90"><circle class="bg" cx="45" cy="45" r="38"/><circle class="fg ram-fg" cx="45" cy="45" r="38" stroke="#ffd93d" stroke-dasharray="238.76" stroke-dashoffset="238.76"/></svg>
<div class="value" id="ram-val">0%</div>
<div class="sub-value" id="ram-used">-</div>
</div>
<div class="detail">Total: <strong id="ram-total">-</strong></div>
</div>
<div class="card">
<div class="label">ZRAM</div>
<div class="circle">
<svg viewBox="0 0 90 90"><circle class="bg" cx="45" cy="45" r="38"/><circle class="fg zram-fg" cx="45" cy="45" r="38" stroke="#a66cff" stroke-dasharray="238.76" stroke-dashoffset="238.76"/></svg>
<div class="value" id="zram-val">0%</div>
<div class="sub-value" id="zram-used">-</div>
</div>
<div class="detail">Total: <strong id="zram-total">-</strong></div>
</div>
<div class="card">
<div class="label">SWAP</div>
<div class="circle">
<svg viewBox="0 0 90 90"><circle class="bg" cx="45" cy="45" r="38"/><circle class="fg swap-fg" cx="45" cy="45" r="38" stroke="#ff6b6b" stroke-dasharray="238.76" stroke-dashoffset="238.76"/></svg>
<div class="value" id="swap-val">0%</div>
<div class="sub-value" id="swap-used">-</div>
</div>
<div class="detail">Total: <strong id="swap-total">-</strong></div>
</div>
<div class="card">
<div class="label">SDCARD</div>
<div class="circle">
<svg viewBox="0 0 90 90"><circle class="bg" cx="45" cy="45" r="38"/><circle class="fg disk-fg" cx="45" cy="45" r="38" stroke="#00ff88" stroke-dasharray="238.76" stroke-dashoffset="238.76"/></svg>
<div class="value" id="disk-val">0%</div>
<div class="sub-value" id="disk-used">-</div>
</div>
<div class="detail">Total: <strong id="disk-total">-</strong></div>
</div>
</div>

<div class="network-card">
<div class="label">Network</div>
<div class="bar-group">
<div class="bar-label"><span><span class="tag">RX</span></span><span class="speed" id="rx-speed">0 B/s</span></div>
<div class="bar-track"><div class="bar-fill rx" id="rx-bar"></div></div>
</div>
<div class="bar-group">
<div class="bar-label"><span><span class="tag">TX</span></span><span class="speed" id="tx-speed">0 B/s</span></div>
<div class="bar-track"><div class="bar-fill tx" id="tx-bar"></div></div>
</div>
<div class="total-row">
<span>Total RX: <strong id="rx-total">-</strong></span>
<span>Total TX: <strong id="tx-total">-</strong></span>
</div>
</div>

<div class="nav-grid">
<a class="nav-btn blog" href="/blog" target="_blank"><span class="icon">&#128221;</span><span>Blog</span><span style="font-size:.75em;color:#5a6a8a;margin-top:2px">Artikel</span></a>
<a class="nav-btn files" href="http://IP_SERVER:8081" target="_blank"><span class="icon">&#128193;</span><span>FileBrowser</span><span style="font-size:.75em;color:#5a6a8a;margin-top:2px">Manajemen File</span></a>
<a class="nav-btn nvr" href="http://IP_SERVER:8765" target="_blank"><span class="icon">&#128250;</span><span>NVR</span><span style="font-size:.75em;color:#5a6a8a;margin-top:2px">CCTV</span></a>
<a class="nav-btn status" href="http://IP_SERVER:7681" target="_blank"><span class="icon">&#128187;</span><span>Status</span><span style="font-size:.75em;color:#5a6a8a;margin-top:2px">Terminal</span></a>
<button class="nav-btn donate" onclick="openDonasi()"><span class="icon">&#128155;</span><span>Donasi</span><span style="font-size:.75em;color:#5a6a8a;margin-top:2px">Dukung Kami</span></button>
</div>
</div>

<div class="modal-overlay" id="donasi-modal">
<div class="modal">
<button class="close" onclick="closeDonasi()">&times;</button>
<h2>&#128155; Support My Home Server</h2>
<p style="text-align:center;font-size:.82em;color:#8892a4;margin-bottom:16px">Terima kasih telah menggunakan My Home Server.<br>Dukungan Anda sangat berarti untuk pengembangan.</p>
<div class="payment"><div class="bank">DANA</div><div class="number">085323073037</div><div style="font-size:.78em;color:#5a6a8a;margin-top:2px">MOCHVPN</div></div>
<div class="payment"><div class="bank">Mandiri</div><div class="number">1310014031126</div><div style="font-size:.78em;color:#5a6a8a;margin-top:2px">a.n. Moh Agus Budiman</div></div>
<div class="payment"><div class="bank">BNI</div><div class="number">2027537451</div><div style="font-size:.78em;color:#5a6a8a;margin-top:2px">a.n. Moh Agus Budiman</div></div>
<div class="qris"><img src="https://raw.githubusercontent.com/budijoi/budijoi.github.io/refs/heads/main/QRDANA2.JPG" alt="QRIS DANA" loading="lazy"><div style="font-size:.75em;color:#5a6a8a;margin-top:4px">Scan QRIS via DANA</div></div>
<a class="whatsapp-btn" href="https://wa.me/6288224553181?text=Halo%20kak%2C%20saya%20mau%20konfirmasi%20donasi%20untuk%20My%20Home%20Server" target="_blank">&#128242; Konfirmasi via WhatsApp</a>
<div class="note">Setelah transfer, konfirmasi via WhatsApp ya :)</div>
</div>
</div>

<script>
const CIRC=238.76;
function updateStats(){
fetch('/api/stats').then(r=>r.json()).then(d=>{
const c=p=>Math.max(0,CIRC-(p/100)*CIRC);
document.getElementById('hostname').textContent=d.hostname;
document.getElementById('ip').textContent=d.ip;
document.getElementById('uptime').textContent=d.uptime;
document.getElementById('cpu-val').textContent=d.cpu_percent+'%';
document.getElementById('cpu-temp').textContent=d.cpu_temp+'\u00B0C';
document.getElementById('cpu-freq').textContent=d.cpu_freq;
document.querySelector('.cpu-fg').setAttribute('stroke-dashoffset',c(d.cpu_percent));
if(d.cpu_temp>70) document.querySelector('.cpu-fg').setAttribute('stroke','#ff6b6b');
else if(d.cpu_temp>55) document.querySelector('.cpu-fg').setAttribute('stroke','#ffd93d');
else document.querySelector('.cpu-fg').setAttribute('stroke','#00d4ff');
document.getElementById('ram-val').textContent=d.ram_percent+'%';
document.getElementById('ram-used').textContent=d.ram_used_fmt;
document.getElementById('ram-total').textContent=d.ram_total_fmt;
document.querySelector('.ram-fg').setAttribute('stroke-dashoffset',c(d.ram_percent));
document.getElementById('zram-val').textContent=d.zram_percent+'%';
document.getElementById('zram-used').textContent=d.zram_used_fmt;
document.getElementById('zram-total').textContent=d.zram_total_fmt;
document.querySelector('.zram-fg').setAttribute('stroke-dashoffset',c(d.zram_percent));
document.getElementById('swap-val').textContent=d.swap_percent+'%';
document.getElementById('swap-used').textContent=d.swap_used_fmt;
document.getElementById('swap-total').textContent=d.swap_total_fmt;
document.querySelector('.swap-fg').setAttribute('stroke-dashoffset',c(d.swap_percent));
document.getElementById('disk-val').textContent=d.disk_percent+'%';
document.getElementById('disk-used').textContent=d.disk_used_fmt;
document.getElementById('disk-total').textContent=d.disk_total_fmt;
document.querySelector('.disk-fg').setAttribute('stroke-dashoffset',c(d.disk_percent));
document.getElementById('rx-speed').textContent=d.rx_speed+'/s';
document.getElementById('tx-speed').textContent=d.tx_speed+'/s';
document.getElementById('rx-total').textContent=d.rx_total_fmt;
document.getElementById('tx-total').textContent=d.tx_total_fmt;
const m=125000000;
const pb=x=>Math.min(100,(fb(x)/m)*100);
document.getElementById('rx-bar').style.width=pb(d.rx_speed)+'%';
document.getElementById('tx-bar').style.width=pb(d.tx_speed)+'%';
}).catch(()=>{});
}
function fb(s){if(!s)return 0;const v=parseFloat(s);if(s.includes('TB'))return v*1099511627776;if(s.includes('GB'))return v*1073741824;if(s.includes('MB'))return v*1048576;if(s.includes('KB'))return v*1024;return v}
function openDonasi(){document.getElementById('donasi-modal').classList.add('active')}
function closeDonasi(){document.getElementById('donasi-modal').classList.remove('active')}
document.getElementById('donasi-modal').addEventListener('click',function(e){if(e.target===this)closeDonasi()});
updateStats();setInterval(updateStats,3000);
</script>
</body>
</html>
HTMLEOF
  ok "Dashboard template HTML dibuat"

  info "Memperbaiki IP di template..."
  local ip_addr
  ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [ -n "$ip_addr" ]; then
    sed -i "s/IP_SERVER/$ip_addr/g" "$DASHBOARD_DIR/templates/index.html"
    ok "IP $ip_addr terpasang di navigasi"
  fi

  info "Membuat blog static..."
  cat > "$BLOG_DIR/index.html" << 'BLOGEOF'
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Blog - My Home Server</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',system-ui,sans-serif;background:#0a0e17;color:#e0e6ed;padding:20px}
.container{max-width:800px;margin:0 auto}
.header{text-align:center;padding:30px 20px;background:linear-gradient(135deg,#131a2b,#1a2340);border-radius:16px;margin-bottom:24px;border:1px solid #1e2a45}
.header h1{font-size:1.5em;background:linear-gradient(135deg,#00d4ff,#00ff88);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
.header .nav-link{display:inline-block;margin-top:10px;color:#00d4ff;text-decoration:none;font-size:.85em}
.header .nav-link:hover{color:#00ff88}
.post{background:#131a2b;border-radius:14px;padding:24px;margin-bottom:16px;border:1px solid #1e2a45}
.post h2{font-size:1.15em;margin-bottom:8px;color:#00d4ff}
.post .date{font-size:.78em;color:#5a6a8a;margin-bottom:12px}
.post p{font-size:.9em;line-height:1.7;color:#c0c8d6}
.post ul{font-size:.9em;line-height:1.7;color:#c0c8d6;padding-left:20px}
.post code{background:#0f1625;padding:2px 8px;border-radius:4px;font-size:.85em;color:#ffd93d}
.footer{text-align:center;padding:20px;color:#5a6a8a;font-size:.8em}
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>Catatan Perjalanan</h1>
<p style="color:#8892a4;font-size:.85em;margin-top:6px">My Home Server - STB B860H</p>
<a class="nav-link" href="/">&larr; Kembali ke Dashboard</a>
</div>
<div class="post">
<h2>Selamat Datang di My Home Server</h2>
<div class="date">12 Juni 2026</div>
<p>Setelah berhasil memulihkan STB B860H dengan eMMC rusak, akhirnya server rumahan ini berjalan menggunakan SD Card sebagai media penyimpanan utama.</p>
<p style="margin-top:10px">Spesifikasi perangkat:</p>
<ul style="margin-top:6px">
<li><strong>SOC:</strong> Amlogic S905X (ARM Cortex-A53)</li>
<li><strong>RAM:</strong> 1 GB DDR3</li>
<li><strong>Penyimpanan:</strong> SD Card (eMMC rusak)</li>
<li><strong>Sistem:</strong> Armbian (Linux 6.x)</li>
</ul>
</div>
<div class="post">
<h2>Fitur yang Tersedia</h2>
<div class="date">12 Juni 2026</div>
<p>Server ini menjalankan beberapa layanan sekaligus:</p>
<ul>
<li><strong>Dashboard Monitor</strong> - Pantau CPU, RAM, ZRAM, SWAP, disk, dan jaringan secara real-time</li>
<li><strong>FileBrowser</strong> - Kelola file via web browser</li>
<li><strong>CCTV NVR</strong> - Rekaman kamera keamanan 24 jam</li>
<li><strong>Cloudflare Tunnel</strong> - Akses server dari luar tanpa IP publik</li>
<li><strong>Blog</strong> - Catatan dan dokumentasi</li>
</ul>
</div>
<div class="post">
<h2>Optimasi untuk S905X</h2>
<div class="date">12 Juni 2026</div>
<p>Agar server tetap responsif dengan RAM 1 GB, beberapa optimasi diterapkan:</p>
<ul>
<li>ZRAM 512 MB untuk kompresi memori</li>
<li>SWAP file 2 GB di SD Card</li>
<li>Swappiness rendah agar lebih mengutamakan ZRAM</li>
<li>I/O scheduler cfq untuk SD Card</li>
<li>Read-ahead buffer disesuaikan</li>
</ul>
</div>
<div class="footer"><p>My Home Server &mdash; Dibuat dengan penuh dedikasi</p></div>
</div>
</body>
</html>
BLOGEOF
  ok "Blog static dibuat"

  # ===================== SECTION 6 =====================
  section "6" "FILEBROWSER"

  info "Menginstal FileBrowser..."
  mkdir -p "$FILEBROWSER_DIR"

  if [ -f "/usr/local/bin/filebrowser" ]; then
    ok "FileBrowser sudah terinstal"
  else
    step "Mengunduh FileBrowser untuk ARM64..."
    local fb_ver
    fb_ver=$(curl -s https://api.github.com/repos/filebrowser/filebrowser/releases/latest 2>/dev/null | grep tag_name | cut -d'"' -f4)
    fb_ver=${fb_ver:-v2.31.0}
    wget -q "https://github.com/filebrowser/filebrowser/releases/download/${fb_ver}/filebrowser-linux-arm64-${fb_ver}.tar.gz" -O /tmp/filebrowser.tar.gz 2>/dev/null &
    spinner $! "Mengunduh FileBrowser ${fb_ver}"
    if [ -f /tmp/filebrowser.tar.gz ]; then
      tar xzf /tmp/filebrowser.tar.gz -C /tmp/ 2>/dev/null
      mv /tmp/filebrowser /usr/local/bin/filebrowser 2>/dev/null
      chmod +x /usr/local/bin/filebrowser
      rm -f /tmp/filebrowser.tar.gz
      ok "FileBrowser ${fb_ver} terinstal"
    else
      warn "Gagal mengunduh FileBrowser. Coba metode alternatif..."
      apt-get install -y -qq filebrowser 2>/dev/null || true
    fi
  fi

  if command -v filebrowser &>/dev/null; then
    step "Membuat direktori penyimpanan..."
    mkdir -p /storage/My\ Document
    mkdir -p /storage/My\ Music
    mkdir -p /storage/My\ Pictures
    mkdir -p /storage/My\ Videos
    mkdir -p /storage/My\ Videos/NVR
    ok "Folder penyimpanan dibuat"

    step "Mengkonfigurasi database FileBrowser..."
    if [ ! -f "$FILEBROWSER_DIR/filebrowser.db" ]; then
      filebrowser config init --address=0.0.0.0 --port=8081 \
        --root=/storage --scope=/storage \
        --database="$FILEBROWSER_DIR/filebrowser.db" 2>/dev/null
      filebrowser users add admin moch1234 --perm.admin \
        --database="$FILEBROWSER_DIR/filebrowser.db" 2>/dev/null
      ok "User admin / moch1234 ditambahkan"
    else
      ok "Database FileBrowser sudah ada"
    fi

    cat > /etc/systemd/system/filebrowser.service << 'FBEOF'
[Unit]
Description=FileBrowser - My Home Server
After=network.target

[Service]
ExecStart=/usr/local/bin/filebrowser -d /opt/filebrowser/filebrowser.db -a 0.0.0.0 -p 8081 -r /storage -s /storage
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
FBEOF
    systemctl daemon-reload 2>/dev/null
    systemctl enable filebrowser.service 2>/dev/null
    systemctl start filebrowser.service 2>/dev/null
    ok "FileBrowser service berjalan di port 8081"
  else
    err "FileBrowser gagal diinstal"
  fi

  # ===================== SECTION 7 =====================
  section "7" "CCTV NVR (motionEye)"

  info "Menginstal motionEye NVR..."

  if command -v motioneye &>/dev/null; then
    ok "motionEye sudah terinstal"
  else
    step "Menginstal motionEye via pip..."
    pip3 install motioneye 2>/dev/null &
    spinner $! "Menginstal motionEye"
    if command -v motioneye &>/dev/null; then
      ok "motionEye terinstal"
    else
      warn "Instalasi motionEye via pip gagal, coba metode lain..."
    fi
  fi

  if command -v motioneye &>/dev/null || [ -f "/usr/local/bin/motioneye" ]; then
    step "Menyiapkan direktori motionEye..."
    mkdir -p /etc/motioneye
    mkdir -p /var/lib/motioneye

    if [ ! -f "/etc/motioneye/motioneye.conf" ]; then
      motioneye_init 2>/dev/null || true
    fi

    step "Menambahkan kamera 192.168.101.6..."
    local cam_dir="/var/lib/motioneye/Camera1"
    mkdir -p "$cam_dir"
    mkdir -p "/storage/My Videos/NVR"

    cat > /etc/motioneye/camera-1.conf << 'CAMEOF'
camera_id = 1
camera_name = Camera Depan
netcam_url = http://192.168.101.6/video.mjpg
# Sesuaikan user/pass kamera jika diperlukan
# netcam_user = admin
# netcam_pass = password_kamera
target_dir = /storage/My Videos/NVR
width = 1280
height = 720
framerate = 10
rotate = 0
text_left = CAM 1
text_right = %Y-%m-%d %T
movie_codec = mp4
movie_fps = 10
movie_quality = 75
snapshot_interval = 0
snapshot_name = %Y%m%d%H%M%S
emulate_motion = true
threshold = 1500
event_gap = 60
output_pictures = off
output_debug_pictures = off
CAMEOF
    ok "Kamera 192.168.101.6 ditambahkan (sesuaikan user/pass jika kamera membutuhkan auth)"

    cat > /etc/systemd/system/motioneye.service << 'MEYEOF'
[Unit]
Description=motionEye NVR - My Home Server
After=network.target

[Service]
ExecStart=/usr/local/bin/meyectl startserver -c /etc/motioneye/motioneye.conf
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
MEYEOF

    systemctl daemon-reload 2>/dev/null
    systemctl enable motioneye.service 2>/dev/null
    systemctl start motioneye.service 2>/dev/null
    ok "motionEye berjalan di port 8765"
  else
    err "motionEye gagal diinstal. Anda dapat menginstalnya manual nanti."
    warn "Jalankan: pip3 install motioneye && motioneye_init"
  fi

  # ===================== SECTION 8 =====================
  section "8" "CLOUDFLARE TUNNEL"

  info "Menyiapkan Cloudflare Tunnel..."

  if command -v cloudflared &>/dev/null; then
    ok "Cloudflared sudah terinstal"
  else
    step "Mengunduh Cloudflared untuk ARM64..."
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" -O /usr/local/bin/cloudflared 2>/dev/null &
    spinner $! "Mengunduh Cloudflared"
    if [ -f /usr/local/bin/cloudflared ]; then
      chmod +x /usr/local/bin/cloudflared
      ok "Cloudflared terinstal"
    else
      err "Gagal mengunduh Cloudflared"
      warn "Anda dapat menginstalnya manual: https://github.com/cloudflare/cloudflared"
    fi
  fi

  if command -v cloudflared &>/dev/null; then
    mkdir -p "$CLOUDFLARED_DIR"

    echo ""
    echo -e "  ${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║            KONFIGURASI CLOUDFLARE TUNNEL        ${NC}"
    echo -e "  ${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${WHITE}Cloudflare Tunnel memungkinkan akses server dari luar${NC}"
    echo -e "  ${WHITE}tanpa perlu IP publik.${NC}"
    echo ""
    echo -e "  ${CYAN}Syarat:${NC}"
    echo -e "  - Akun Cloudflare (gratis)"
    echo -e "  - Domain yang terkelola di Cloudflare"
    echo ""

    if confirm "Apakah Anda ingin mengkonfigurasi Cloudflare Tunnel sekarang?"; then
      echo ""
      echo -e -n "  ${WHITE}Masukkan domain Anda (contoh: server.example.com): ${NC}"
      read -r CLOUD_DOMAIN

      if [ -n "$CLOUD_DOMAIN" ]; then
        echo ""
        info "Memulai autentikasi Cloudflare..."
        echo ""
        echo -e "  ${YELLOW}Akan terbuka URL untuk login ke Cloudflare.${NC}"
        echo -e "  ${YELLOW}Silakan login dan pilih domain Anda.${NC}"
        echo ""
        wait_enter

        cloudflared tunnel login 2>/dev/null

        if [ -f "$CLOUDFLARED_DIR/cert.pem" ]; then
          ok "Autentikasi berhasil!"

          step "Membuat tunnel..."
          cloudflared tunnel create homeserver 2>/dev/null
          local tunnel_id
          tunnel_id=$(cloudflared tunnel list 2>/dev/null | grep homeserver | awk '{print $1}')
          if [ -z "$tunnel_id" ]; then
            tunnel_id=$(ls "$CLOUDFLARED_DIR"/*.json 2>/dev/null | head -1 | xargs basename | sed 's/.json//')
          fi

          if [ -n "$tunnel_id" ]; then
            ok "Tunnel ID: $tunnel_id"

            cat > "$CLOUDFLARED_DIR/config.yml" << 'TUNEOF'
tunnel: TUNNEL_ID
credentials-file: /root/.cloudflared/TUNNEL_ID.json
ingress:
  - hostname: DASHBOARD_DOMAIN
    service: http://localhost:8080
  - hostname: FILES_DOMAIN
    service: http://localhost:8081
  - hostname: NVR_DOMAIN
    service: http://localhost:8765
  - hostname: STATUS_DOMAIN
    service: http://localhost:7681
  - service: http_status:404
TUNEOF
            sed -i "s/TUNNEL_ID/$tunnel_id/g" "$CLOUDFLARED_DIR/config.yml"
            sed -i "s/DASHBOARD_DOMAIN/dashboard.$CLOUD_DOMAIN/g" "$CLOUDFLARED_DIR/config.yml"
            sed -i "s/FILES_DOMAIN/files.$CLOUD_DOMAIN/g" "$CLOUDFLARED_DIR/config.yml"
            sed -i "s/NVR_DOMAIN/nvr.$CLOUD_DOMAIN/g" "$CLOUDFLARED_DIR/config.yml"
            sed -i "s/STATUS_DOMAIN/status.$CLOUD_DOMAIN/g" "$CLOUDFLARED_DIR/config.yml"
            ok "Konfigurasi tunnel dibuat untuk domain $CLOUD_DOMAIN"

            step "Mengatur DNS records..."
            cloudflared tunnel route dns homeserver "dashboard.$CLOUD_DOMAIN" 2>/dev/null
            cloudflared tunnel route dns homeserver "files.$CLOUD_DOMAIN" 2>/dev/null
            cloudflared tunnel route dns homeserver "nvr.$CLOUD_DOMAIN" 2>/dev/null
            cloudflared tunnel route dns homeserver "status.$CLOUD_DOMAIN" 2>/dev/null
            ok "DNS records dibuat"

            cat > /etc/systemd/system/cloudflared.service << 'CLFEOF'
[Unit]
Description=Cloudflare Tunnel - My Home Server
After=network.target

[Service]
ExecStart=/usr/local/bin/cloudflared tunnel run homeserver
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
CLFEOF
            systemctl daemon-reload 2>/dev/null
            systemctl enable cloudflared.service 2>/dev/null
            systemctl start cloudflared.service 2>/dev/null
            ok "Cloudflare Tunnel berjalan!"
          else
            warn "Gagal mendapatkan tunnel ID. Silakan konfigurasi manual."
          fi
        else
          err "Autentikasi gagal. Silakan jalankan 'cloudflared tunnel login' manual."
        fi
      fi
    else
      info "Cloudflare Tunnel dilewati. Anda dapat mengkonfigurasinya nanti."
    fi
  fi

  # ===================== SECTION 9 =====================
  section "9" "TTYD + BTOP (Terminal via Web)"

  info "Mengkonfigurasi TTYD dengan BTOP..."

  if command -v ttyd &>/dev/null; then
    ok "TTYD terinstal"

    cat > /etc/systemd/system/ttyd.service << 'TTYDEOF'
[Unit]
Description=TTYD - Web Terminal (BTOP)
After=network.target

[Service]
ExecStart=/usr/bin/ttyd -p 7681 -c admin:moch1234 btop
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
TTYDEOF

    systemctl daemon-reload 2>/dev/null
    systemctl enable ttyd.service 2>/dev/null
    systemctl start ttyd.service 2>/dev/null
    ok "TTYD berjalan di port 7681 (user: admin / pass: moch1234)"
  else
    warn "TTYD tidak terinstal. Mencoba menginstal..."
    apt-get install -y -qq ttyd 2>/dev/null || true
    if command -v ttyd &>/dev/null; then
      systemctl restart ttyd.service 2>/dev/null || true
      ok "TTYD terinstal dan berjalan"
    else
      err "TTYD gagal diinstal. Silakan instal manual: apt install ttyd"
    fi
  fi

  # Create dashboard service (must be before enable loop)
  cat > /etc/systemd/system/homeserver-dashboard.service << 'DEOF'
[Unit]
Description=My Home Server Dashboard
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/homeserver/dashboard/app.py
WorkingDirectory=/opt/homeserver/dashboard
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
DEOF

  # ===================== SECTION 10 =====================
  section "10" "MEMULAI SEMUA SERVICE"

  info "Memulai dan mengaktifkan semua service..."

  systemctl daemon-reload 2>/dev/null

  for svc in homeserver-dashboard filebrowser motioneye cloudflared ttyd; do
    systemctl enable "$svc.service" 2>/dev/null || true
    systemctl start "$svc.service" 2>/dev/null || true
  done

  ok "Semua service telah dimulai"

  # ===================== SECTION 11 =====================
  section "11" "FIREWALL (UFW)"

  info "Mengkonfigurasi firewall..."

  ufw --force reset 2>/dev/null
  ufw default deny incoming 2>/dev/null
  ufw default allow outgoing 2>/dev/null
  ufw allow ssh 2>/dev/null
  ufw allow 8080/tcp comment "Dashboard"
  ufw allow 8081/tcp comment "FileBrowser"
  ufw allow 8765/tcp comment "motionEye"
  ufw allow 7681/tcp comment "TTYD"
  ufw --force enable 2>/dev/null
  ok "Firewall dikonfigurasi"

  # ===================== SUMMARY =====================
  section "SELESAI" "INSTALASI BERHASIL!"

  local ip_addr
  ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
  [ -z "$ip_addr" ] && ip_addr="(cek IP Anda)"

  echo ""
  echo -e "  ${GREEN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "  ${GREEN}║        INSTALASI SELESAI!        ${NC}"
  echo -e "  ${GREEN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${WHITE}Akses layanan Anda di:${NC}"
  echo ""
  echo -e "  ${CYAN}  Dashboard :${NC} http://${ip_addr}:8080"
  echo -e "  ${CYAN}  Blog      :${NC} http://${ip_addr}:8080/blog"
  echo -e "  ${CYAN}  FileBrowser:${NC} http://${ip_addr}:8081"
  echo -e "  ${CYAN}  NVR CCTV  :${NC} http://${ip_addr}:8765"
  echo -e "  ${CYAN}  Status    :${NC} http://${ip_addr}:7681"
  echo ""
  echo -e "  ${YELLOW}Kredensial:${NC}"
  echo -e "  FileBrowser : admin / moch1234"
  echo -e "  TTYD        : admin / moch1234"
  echo ""
  echo -e "  ${YELLOW}Penyimpanan:${NC}"
  echo -e "  My Document : /storage/My Document/"
  echo -e "  My Music    : /storage/My Music/"
  echo -e "  My Pictures : /storage/My Pictures/"
  echo -e "  My Videos   : /storage/My Videos/"
  echo -e "  NVR Record  : /storage/My Videos/NVR/"
  echo ""
  echo -e "  ${YELLOW}Optimasi:${NC}"
  echo -e "  ZRAM        : 512 MB"
  echo -e "  SWAP        : 2 GB"
  echo -e "  Swappiness  : 10"
  echo ""

  echo -e "  ${WHITE}Terima kasih telah menggunakan My Home Server!${NC}"
  echo -e "  ${WHITE}Dukung pengembangan dengan tombol Donasi di Dashboard.${NC}"
  echo ""
  echo -e "  ${MAGENTA}WA Admin : 085323073037${NC}"
  echo ""

  if [ -n "$CLOUD_DOMAIN" ] && [ -n "$tunnel_id" ]; then
    echo -e "  ${GREEN}Cloudflare Tunnel aktif! Akses dari luar:${NC}"
    echo -e "  https://dashboard.$CLOUD_DOMAIN"
    echo -e "  https://files.$CLOUD_DOMAIN"
    echo -e "  https://nvr.$CLOUD_DOMAIN"
    echo -e "  https://status.$CLOUD_DOMAIN"
    echo ""
  fi

  echo -e "  ${YELLOW}Reboot direkomendasikan untuk menerapkan semua perubahan.${NC}"
  echo ""
  if confirm "Reboot sekarang?"; then
    info "Rebooting..."
    reboot
  else
    info "Jangan lupa reboot nanti: sudo reboot"
  fi
}

# ============================================================
# RUN MAIN
# ============================================================
main "$@"
