#!/bin/bash
# setup-feeds.sh — Prepare stable Daed + MosDNS v5 + Tailscale packages
set -euo pipefail

OPENWRT_DIR="${1:-$(pwd)}"

if [ ! -f "$OPENWRT_DIR/feeds.conf.default" ]; then
  echo "ERROR: Not in ImmortalWrt root directory: $OPENWRT_DIR"
  echo "Usage: $0 [openwrt-dir]"
  exit 1
fi

cd "$OPENWRT_DIR"

echo "=========================================="
echo "  Updating ImmortalWrt 25.12 feeds"
echo "=========================================="

# Remove stale custom feed entries before adding our dedicated Daed feed.
sed -i '/openwrt-daede/d' feeds.conf 2>/dev/null || true
sed -i '/sbwml\/luci-app-mosdns/d' feeds.conf 2>/dev/null || true
sed -i '/sbwml\/v2ray-geodata/d' feeds.conf 2>/dev/null || true
sed -i '/openwrt\/packages/d' feeds.conf 2>/dev/null || true
sed -i '/immortalwrt\/packages/d' feeds.conf 2>/dev/null || true
sed -i '/^src-git daede /d' feeds.conf 2>/dev/null || true

cat >> feeds.conf <<'FEED'
src-git daede https://github.com/kenzok8/openwrt-daede.git;main
FEED

echo "=== feeds.conf ==="
cat feeds.conf

echo "=== Updating feeds ==="
./scripts/feeds update -a

echo "=== Installing Daed packages from dedicated feed ==="
./scripts/feeds install -p daede dae daed luci-app-daede

echo "=== Preparing MosDNS v5 ==="
rm -rf \
  feeds/packages/net/mosdns \
  package/feeds/packages/mosdns \
  package/mosdns \
  package/luci-app-mosdns \
  package/geo2txt \
  /tmp/luci-app-mosdns

git clone --depth 1 --single-branch --branch v5 \
  https://github.com/sbwml/luci-app-mosdns \
  /tmp/luci-app-mosdns

mkdir -p package/mosdns package/luci-app-mosdns package/geo2txt
cp -a /tmp/luci-app-mosdns/mosdns/. package/mosdns/
cp -a /tmp/luci-app-mosdns/luci-app-mosdns/. package/luci-app-mosdns/
if [ -d /tmp/luci-app-mosdns/geo2txt ]; then
  cp -a /tmp/luci-app-mosdns/geo2txt/. package/geo2txt/
fi
rm -rf /tmp/luci-app-mosdns

echo "=== Preparing v2ray geodata ==="
rm -rf feeds/packages/net/v2ray-geodata package/feeds/packages/v2ray-geodata package/v2ray-geodata

git clone --depth 1 --single-branch \
  https://github.com/sbwml/v2ray-geodata \
  package/v2ray-geodata

echo "=== Installing Tailscale from the standard packages feed ==="
./scripts/feeds install tailscale

echo "=== Validating required package sources ==="
checks=(
  "package/feeds/daede/dae/Makefile"
  "package/feeds/daede/daed/Makefile"
  "package/feeds/daede/luci-app-daede/Makefile"
  "package/mosdns/Makefile"
  "package/luci-app-mosdns/Makefile"
  "package/geo2txt/Makefile"
  "package/v2ray-geodata/Makefile"
  "feeds/packages/net/tailscale/Makefile"
)

for file in "${checks[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✓ $file"
  else
    echo "  ❌ $file"
    exit 1
  fi
done

echo "=== Package preparation completed successfully ==="
