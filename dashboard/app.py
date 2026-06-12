#!/usr/bin/env python3
import os
import time
import threading
import subprocess
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
        if t > 0:
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
            val = parts[1].strip().split()[0]
            try:
                mem[key] = int(val)
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
                if iface in line:
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
        result = subprocess.run(
            ['ip', '-4', 'addr', 'show', iface],
            capture_output=True, text=True, timeout=5
        )
        for line in result.stdout.split('\n'):
            if 'inet ' in line:
                return line.split()[1].split('/')[0]
    except:
        pass
    try:
        result = subprocess.run(
            ['hostname', '-I'], capture_output=True, text=True, timeout=5
        )
        return result.stdout.strip().split()[0]
    except:
        return 'N/A'


def get_uptime():
    try:
        with open('/proc/uptime') as f:
            seconds = float(f.read().split()[0])
        days = int(seconds // 86400)
        hours = int((seconds % 86400) // 3600)
        minutes = int((seconds % 3600) // 60)
        if days > 0:
            return f'{days}d {hours}h {minutes}m'
        return f'{hours}h {minutes}m'
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

        zram_total = mem.get('SwapTotal', 0) - mem.get('SwapFree', 0) + mem.get('SwapCached', 0)
        zram_used = mem.get('SwapCached', 0)
        zram_total_real = mem.get('SwapTotal', 0)
        zram_percent = round(zram_used / zram_total_real * 100, 1) if zram_total_real else 0

        swap_total = mem.get('SwapTotal', 0)
        swap_free = mem.get('SwapFree', 0)
        swap_used = swap_total - swap_free
        swap_percent = round(swap_used / swap_total * 100, 1) if swap_total else 0

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
            'cpu_percent': cpu_percent,
            'cpu_temp': cpu_temp,
            'cpu_freq': cpu_freq,
            'ram_total': ram_total,
            'ram_used': ram_used,
            'ram_percent': ram_percent,
            'zram_total': zram_total_real,
            'zram_used': zram_used,
            'zram_percent': zram_percent,
            'swap_total': swap_total,
            'swap_used': swap_used,
            'swap_percent': swap_percent,
            'disk_total': disk['total'],
            'disk_used': disk['used'],
            'disk_percent': disk['percent'],
            'rx_bytes': rx,
            'tx_bytes': tx,
            'rx_speed': rx_speed,
            'tx_speed': tx_speed,
            'hostname': hostname,
            'ip': ip,
            'uptime': uptime,
        })


def format_bytes(b):
    if b >= 1099511627776:
        return f'{b/1099511627776:.1f} TB'
    if b >= 1073741824:
        return f'{b/1073741824:.1f} GB'
    if b >= 1048576:
        return f'{b/1048576:.1f} MB'
    if b >= 1024:
        return f'{b/1024:.1f} KB'
    return f'{b} B'


@app.route('/api/stats')
def api_stats():
    s = stats
    return jsonify({
        'cpu_percent': s['cpu_percent'],
        'cpu_temp': s['cpu_temp'],
        'cpu_freq': s['cpu_freq'],
        'ram_used': s['ram_used'],
        'ram_total': s['ram_total'],
        'ram_percent': s['ram_percent'],
        'ram_used_fmt': format_bytes(s['ram_used']),
        'ram_total_fmt': format_bytes(s['ram_total']),
        'zram_percent': s['zram_percent'],
        'zram_used_fmt': format_bytes(s['zram_used']),
        'zram_total_fmt': format_bytes(s['zram_total']),
        'swap_percent': s['swap_percent'],
        'swap_used_fmt': format_bytes(s['swap_used']),
        'swap_total_fmt': format_bytes(s['swap_total']),
        'disk_percent': s['disk_percent'],
        'disk_used_fmt': format_bytes(s['disk_used']),
        'disk_total_fmt': format_bytes(s['disk_total']),
        'rx_speed': format_bytes(s['rx_speed']),
        'tx_speed': format_bytes(s['tx_speed']),
        'rx_total_fmt': format_bytes(s['rx_bytes']),
        'tx_total_fmt': format_bytes(s['tx_bytes']),
        'hostname': s['hostname'],
        'ip': s['ip'],
        'uptime': s['uptime'],
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
