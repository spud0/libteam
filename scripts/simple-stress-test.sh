#!/bin/bash
set -euo pipefail

echo "[*] Cleaning up old teamd and proxy..."
pkill -f "teamd -t team0" || true
pkill -f "./path/to/proxy-server" || true

rm -f /etc/teamd/team0.conf 
rm -f /tmp/nl-message.sock

echo "[*] Bringing interface down..."
ip link set eth0 down || true

echo "[*] Starting proxy server..."
./path/to/proxy > proxy.log 2>&1 &
sleep 1

echo "[*] Starting teamd..."
/usr/local/bin/teamd -r -t team0 -c '{
  "device": "team0",
  "runner": {
    "name": "lacp",
    "active": true,
    "sys_prio": 100,
    "tx_interval": 30000,
    "port_offset": 0,
    "lacp_key": 1,
    "fast_rate": false
  },
  "ports": {
    "eth0": {}
  }
}' -g -d

sleep 2

echo "[*] Initial team state:"
teamdctl team0 state

echo "[*] Flapping eth1 10,000 times..."
for i in $(seq 1 10000); do
  ip link set eth0 down
  ip link set eth0 up

  # Every 1000 iterations, print status
  if (( i % 1000 == 0 )); then
    echo "[*] Iteration $i status:"
    teamdctl team0 state
  fi
done

echo "[*] Final team status:"
teamdctl team0 state

