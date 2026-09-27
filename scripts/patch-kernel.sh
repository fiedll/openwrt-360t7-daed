#!/bin/bash
# patch-kernel.sh — Enable BTF/BPF options required by Daed
set -euo pipefail

cd "$(dirname "$0")/.."
OPENWRT_DIR="${1:-openwrt}"
[ -d "$OPENWRT_DIR" ] && cd "$OPENWRT_DIR" || {
  echo "Must run from project root or pass openwrt dir"
  exit 1
}

KVER=""
for f in target/linux/generic/config-[0-9]*; do
  [ -f "$f" ] || continue
  v=$(basename "$f" | sed 's/config-//')
  if [ -z "$KVER" ] || [ "$(printf '%s\n%s\n' "$KVER" "$v" | sort -V | tail -1)" = "$v" ]; then
    KVER="$v"
  fi
done

[ -n "$KVER" ] || {
  echo "ERROR: Cannot detect kernel config version"
  exit 1
}

GENERIC_CONFIG="target/linux/generic/config-${KVER}"
echo "Detected kernel config version: $KVER"
echo "Patching: $GENERIC_CONFIG"

set_opt() {
  local f="$1" opt="$2" val="$3"
  [ -f "$f" ] || {
    echo "ERROR: Kernel config not found: $f"
    exit 1
  }
  sed -i "/^${opt}[= ]/d; /^# ${opt} is not set/d" "$f"
  echo "${opt}=${val}" >> "$f"
}

for item in \
  "CONFIG_DEBUG_INFO y" \
  "CONFIG_DEBUG_INFO_REDUCED y" \
  "CONFIG_DEBUG_INFO_BTF y" \
  "CONFIG_DEBUG_INFO_BTF_MODULES y" \
  "CONFIG_BPF y" \
  "CONFIG_BPF_SYSCALL y" \
  "CONFIG_BPF_JIT y" \
  "CONFIG_BPF_JIT_ALWAYS_ON y" \
  "CONFIG_BPF_EVENTS y" \
  "CONFIG_BPF_STREAM_PARSER y" \
  "CONFIG_CGROUP_BPF y" \
  "CONFIG_NET_CLS_BPF m" \
  "CONFIG_NET_ACT_BPF m" \
  "CONFIG_NET_SCH_INGRESS m" \
  "CONFIG_XDP_SOCKETS y" \
  "CONFIG_XDP_SOCKETS_DIAG m" \
  "CONFIG_VETH m"
do
  set -- $item
  set_opt "$GENERIC_CONFIG" "$1" "$2"
done

echo "=== Final BTF/BPF options ==="
grep -E '^(CONFIG_(DEBUG_INFO|BPF|CGROUP_BPF|NET_CLS_BPF|NET_ACT_BPF|NET_SCH_INGRESS|XDP_SOCKETS|VETH))=' "$GENERIC_CONFIG" | sort

echo "=== BTF/BPF patch completed ==="
