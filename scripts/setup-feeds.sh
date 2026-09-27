#!/bin/bash
# setup-feeds.sh — Add custom package feeds for 360T7
set -euo pipefail

OPENWRT_DIR="${1:-$(pwd)}"

if [ ! -f "$OPENWRT_DIR/feeds.conf.default" ]; then
  echo "ERROR: Not in ImmortalWrt root directory"
  echo "Usage: $0 [openwrt-dir]"
  exit 1
fi

cd "$OPENWRT_DIR"

echo "=========================================="
echo "  Adding custom feeds"
echo "=========================================="

sed -i '/openwrt-daede/d' feeds.conf 2>/dev/null || true
sed -i '/sbwml\/luci-app-mosdns/d' feeds.conf 2>/dev/null || true
sed -i '/sbwml\/v2ray-geodata/d' feeds.conf 2>/dev/null || true

cat >> feeds.conf <<'FEED'
src-git daede https://github.com/kenzok8/openwrt-daede.git;main
src-git mosdns https://github.com/sbwml/luci-app-mosdns.git;v5
src-git geodata https://github.com/sbwml/v2ray-geodata.git;master
FEED

echo "=== feeds.conf ==="
cat feeds.conf
echo "=== Updating feeds ==="
./scripts/feeds update -a
echo "=== Installing required custom packages ==="
./scripts/feeds install dae daed luci-app-daede
./scripts/feeds install mosdns luci-app-mosdns geo2txt
./scripts/feeds install v2ray-geoip v2ray-geosite

echo "=== Custom feeds ready ==="
for pkg in dae daed luci-app-daede mosdns luci-app-mosdns geo2txt v2ray-geoip v2ray-geosite; do
  if [ -f "package/feeds/daede/$pkg/Makefile" ] ||      [ -f "package/feeds/mosdns/$pkg/Makefile" ] ||      [ -f "package/feeds/geodata/$pkg/Makefile" ]; then
    echo "  ✓ $pkg"
  else
    echo "  ❌ $pkg"
    exit 1
  fi
done
