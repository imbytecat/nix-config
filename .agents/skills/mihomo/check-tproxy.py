import json
import os
import subprocess
import sys

# 只在新建的网络命名空间内改路由和 nftables，绝不碰宿主机规则。
assert os.readlink("/proc/self/ns/net") != os.readlink("/proc/1/ns/net"), "Run inside unshare --net"
config = json.load(sys.stdin)
constants = config["constants"]
children = []


def run(args, pid=None, text=None):
    prefix = ["nsenter", "--target", str(pid), "--net", "--"] if pid else []
    return subprocess.run(prefix + args, input=text, text=True, capture_output=True, check=True).stdout


def spawn(args, pid=None):
    prefix = ["nsenter", "--target", str(pid), "--net", "--"] if pid else []
    child = subprocess.Popen(prefix + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    children.append(child)
    assert child.stdout.readline().strip() == "READY", child.stderr.read()
    return child


server_code = '''
import select, socket, struct, sys
port, marker, transparent = int(sys.argv[1]), sys.argv[2].encode(), sys.argv[3] == "yes"
sockets = []
for kind in (socket.SOCK_STREAM, socket.SOCK_DGRAM):
    s = socket.socket(socket.AF_INET, kind)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    if transparent:
        s.setsockopt(socket.SOL_IP, socket.IP_TRANSPARENT, 1)
        if kind == socket.SOCK_DGRAM:
            s.setsockopt(socket.SOL_IP, socket.IP_RECVORIGDSTADDR, 1)
    s.bind(("0.0.0.0", port))
    if kind == socket.SOCK_STREAM:
        s.listen()
    sockets.append(s)
print("READY", flush=True)
while True:
    ready, _, _ = select.select(sockets, [], [])
    for s in ready:
        if s.type == socket.SOCK_STREAM:
            conn, _ = s.accept()
            with conn:
                conn.sendall(marker)
        elif transparent:
            _, ancillary, _, peer = s.recvmsg(1024, 1024)
            dst = next(data for level, kind, data in ancillary
                       if level == socket.SOL_IP and kind == socket.IP_RECVORIGDSTADDR)
            address = socket.inet_ntoa(dst[4:8]), struct.unpack("!H", dst[2:4])[0]
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reply:
                reply.setsockopt(socket.SOL_IP, socket.IP_TRANSPARENT, 1)
                reply.bind(address)
                reply.sendto(marker, peer)
        else:
            _, peer = s.recvfrom(1024)
            s.sendto(marker, peer)
'''
client_code = '''
import socket, sys
host, port, protocol = sys.argv[1:]
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM if protocol == "tcp" else socket.SOCK_DGRAM)
s.settimeout(1)
try:
    if protocol == "tcp":
        s.connect((host, int(port)))
        data = s.recv(1024)
    else:
        s.sendto(b"probe", (host, int(port)))
        data, _ = s.recvfrom(1024)
    print(data.decode())
except TimeoutError:
    print("timeout")
finally:
    s.close()
'''


def probe(pid, host, port, expected):
    for protocol in ("tcp", "udp"):
        actual = run([sys.executable, "-c", client_code, host, str(port), protocol], pid).strip()
        print(f"{host}:{port} {protocol}: {actual}", flush=True)
        if actual != expected:
            for child in children:
                if child.poll() is not None:
                    print(child.stderr.read(), file=sys.stderr)
        assert actual == expected, (host, port, protocol, expected, actual)


def forwarded():
    data = json.loads(run(["nft", "-j", "list", "table", "ip", "smoke"]))
    return [expr["counter"]["packets"] for item in data["nftables"]
            for expr in item.get("rule", {}).get("expr", []) if "counter" in expr]


try:
    holders = [spawn(["unshare", "--net", sys.executable, "-u", "-c",
                      "import time; print('READY', flush=True); time.sleep(60)"]) for _ in range(2)]
    client, server = [child.pid for child in holders]
    run(["ip", "link", "set", "lo", "up"])
    for local, peer, pid, subnet in [("lan", "client", client, "10.0.0"), ("wan", "server", server, "203.0.113")]:
        run(["ip", "link", "add", local, "type", "veth", "peer", "name", peer])
        run(["ip", "link", "set", peer, "netns", str(pid)])
        run(["ip", "addr", "add", subnet + ".1/24", "dev", local])
        run(["ip", "link", "set", local, "up"])
        run(["ip", "link", "set", "lo", "up"], pid)
        run(["ip", "addr", "add", subnet + ".2/24", "dev", peer], pid)
        run(["ip", "link", "set", peer, "up"], pid)
        run(["ip", "route", "add", "default", "via", subnet + ".1"], pid)
    run(["ip", "addr", "add", "192.168.50.2/32", "dev", "lo"], server)
    run(["ip", "route", "add", "192.168.50.2/32", "via", "203.0.113.2"])
    # 新 namespace 会继承宿主机的 src_valid_mark，恢复网关不启用该项的默认语义。
    run(["sysctl", "-qw", "net.ipv4.conf.all.src_valid_mark=0", "net.ipv4.conf.default.src_valid_mark=0"])
    run(["sysctl", "-qw", "net.ipv4.ip_forward=1", "net.ipv4.conf.all.rp_filter=0",
         "net.ipv4.conf.default.rp_filter=0", "net.ipv4.conf.lan.rp_filter=0",
         "net.ipv4.conf.wan.rp_filter=0", "net.ipv4.conf.lo.rp_filter=0"])
    table = str(constants["routingTable"])
    run(["ip", "rule", "add", "fwmark", str(constants["routingMark"]), "lookup", table, "priority", "100"])
    run(["ip", "route", "add", "local", "0.0.0.0/0", "dev", "lo", "table", table])
    spawn([sys.executable, "-u", "-c", server_code, "18080", "origin", "no"], server)
    run(["nft", "-f", "-"], text='''table ip smoke {
      chain forward {
        type filter hook forward priority filter; policy accept;
        ip daddr 203.0.113.2 tcp dport 18080 tcp flags & (syn | ack) == syn counter
        ip daddr 203.0.113.2 udp dport 18080 counter
      }
    }
    ''')
    print("Baseline: forwarding works without TPROXY", flush=True)
    probe(client, "203.0.113.2", 18080, "origin")
    before = forwarded()
    assert all(count > 0 for count in before), before
    run(["nft", "-f", "-"], text=config["ruleset"])
    print("Repository rules installed, no transparent listener", flush=True)
    probe(client, "203.0.113.2", 18080, "timeout")
    assert forwarded() == before, (before, forwarded())
    print("Private-address bypass remains reachable", flush=True)
    probe(client, "192.168.50.2", 18080, "origin")
    spawn([sys.executable, "-u", "-c", server_code, str(constants["dnsPort"]), "dns", "no"])
    print("Port 53 still reaches the DNS redirect", flush=True)
    probe(client, "203.0.113.2", 53, "dns")
    proxy = spawn([sys.executable, "-u", "-c", server_code, str(constants["tproxyPort"]), "proxy", "yes"])
    print("Transparent TCP/UDP listeners receive intercepted traffic", flush=True)
    probe(client, "203.0.113.2", 18080, "proxy")
    assert forwarded() == before, (before, forwarded())
    proxy.terminate()
    proxy.wait(timeout=3)
    print("Stopping the listeners fails closed again", flush=True)
    probe(client, "203.0.113.2", 18080, "timeout")
    assert forwarded() == before, (before, forwarded())
    run(["nft", "delete", "table", "ip", "mihomo"])
    print("Removing TPROXY restores forwarding", flush=True)
    probe(client, "203.0.113.2", 18080, "origin")
    print("PASS: TCP/UDP interception, fail-closed, private bypass and DNS redirect", flush=True)
finally:
    for child in reversed(children):
        child.terminate()
        try:
            child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
