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

if ! grep -q "^src-git packages .*;openwrt-25.12$" feeds.conf; then
  echo "ERROR: ImmortalWrt 25.12 packages feed is missing or not branch-pinned"
  grep "^src-git packages " feeds.conf || true
  exit 1
fi

echo "=========================================="
echo "  Updating ImmortalWrt 25.12 feeds"
echo "=========================================="

# ImmortalWrt 25.12 enables the OpenWrt video feed by default. The video
# repository is not needed on 360T7 and its APK index can intermittently be
# truncated, making apk update fail with wget error 8 / unexpected EOF.
# Disable the feed at build time so no video/packages.adb entry is generated
# into /etc/apk/repositories.d/distfeeds.list in the final firmware.
if grep -q "^src-git video " feeds.conf; then
  sed -i 's/^src-git video /# disabled: src-git video /' feeds.conf
fi
if grep -q "^src-git video " feeds.conf; then
  echo "ERROR: video feed is still enabled"
  exit 1
fi

# Remove stale custom feed entries before adding our dedicated Daed feed.
sed -i '/openwrt-daede/d' feeds.conf 2>/dev/null || true
sed -i '/sbwml\/luci-app-mosdns/d' feeds.conf 2>/dev/null || true
sed -i '/sbwml\/v2ray-geodata/d' feeds.conf 2>/dev/null || true
sed -i '/openwrt\/packages/d' feeds.conf 2>/dev/null || true
sed -i '/^src-git daede /d' feeds.conf 2>/dev/null || true

cat >> feeds.conf <<'FEED'
src-git daede https://github.com/kenzok8/openwrt-daede.git;main
FEED

echo "=== feeds.conf ==="
cat feeds.conf
echo "=== Updating feeds ==="
./scripts/feeds update -a

[ -f feeds/packages/net/tailscale/Makefile ] || { echo "ERROR: Tailscale package missing"; exit 1; }
[ -f feeds/packages/lang/golang/golang/Makefile ] || { echo "ERROR: Go host package missing"; exit 1; }

# Install the standard feed packages first. ImmortalWrt 25.12 uses feed-provided
# LuCI packages (including the virtual luci package required by default-settings).
# Without this, CONFIG_PACKAGE_luci=y can survive defconfig but the final APK
# package index has no luci package, causing package/install to fail.
echo "=== Installing standard feed packages ==="
./scripts/feeds install -a

# Verify that the LuCI package tree is actually linked into package/.
[ -f package/feeds/luci/luci/Makefile ] || { echo "ERROR: LuCI package missing after feeds install"; exit 1; }
[ -f package/feeds/luci/luci-base/Makefile ] || { echo "ERROR: luci-base package missing after feeds install"; exit 1; }

echo "=== Installing Daed packages from dedicated feed ==="
# The current kenzok8/openwrt-daede feed contains dae/daed/luci-app-daede,
# but scripts/feeds may omit the two Go packages on some 25.12 metadata
# combinations. Link the package directories explicitly so the source tree
# is deterministic and the packages are always visible to the build system.
mkdir -p package/feeds/daede
for pkg in dae daed luci-app-daede; do
  rm -rf "package/feeds/daede/$pkg"
  ln -s "../../../feeds/daede/$pkg" "package/feeds/daede/$pkg"
done
# We build against the kernel's integrated BTF; do not expose the optional
# standalone vmlinux-btf package as a required build dependency.
rm -rf package/feeds/daede/vmlinux-btf

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
