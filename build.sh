#!/usr/bin/env bash
set -euo pipefail

# Penang / Holi Motorola kernel build wrapper
# Repo layout assumed:
#   <repo-root>/
#     arch/
#     scripts/
#     prebuilts/
#     external/
#
# This adapts Motorola's published "kernel/msm-5.4" instructions to a flattened GitHub tree.

# ---------- user-tunable knobs ----------
TARGET_PRODUCT="${TARGET_PRODUCT:-penang_sb}"
TARGET_BUILD_VARIANT="${TARGET_BUILD_VARIANT:-user}"
JOBS="${JOBS:-$(nproc)}"
DO_HEADERS_INSTALL="${DO_HEADERS_INSTALL:-1}"
DO_MODULES_INSTALL="${DO_MODULES_INSTALL:-1}"
DO_CLEAN_OUT="${DO_CLEAN_OUT:-0}"

# ---------- path setup ----------
REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")"
MY_TOP_DIR="$REPO_ROOT"
KERNEL_DIR="$REPO_ROOT"
OUT_DIR="${OUT_DIR:-$MY_TOP_DIR/out}"
KERNEL_OUT_DIR="${KERNEL_OUT_DIR:-$OUT_DIR}"

# ---------- toolchain ----------
CLANG_DIR="$MY_TOP_DIR/prebuilts/clang/host/linux-x86/clang-r383902b1/bin"
CLANG="$CLANG_DIR/clang"
LD_LLD="$CLANG_DIR/ld.lld"
LLVM_AR="$CLANG_DIR/llvm-ar"
LLVM_NM="$CLANG_DIR/llvm-nm"
LLVM_OBJCOPY="$CLANG_DIR/llvm-objcopy"
LLVM_OBJDUMP="$CLANG_DIR/llvm-objdump"
LLVM_STRIP="$CLANG_DIR/llvm-strip"

AARCH64_CROSS="$MY_TOP_DIR/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-"
ARM32_CROSS="$MY_TOP_DIR/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi-"
HOST_X86_AR="$MY_TOP_DIR/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/bin/x86_64-linux-ar"
HOST_X86_LD="$MY_TOP_DIR/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/bin/x86_64-linux-ld"
AOSP_MAKE="$MY_TOP_DIR/prebuilts/build-tools/linux-x86/bin/make"

# ---------- sanity checks ----------
need_exec() {
  local p="$1"
  if [[ ! -x "$p" ]]; then
    echo "ERROR: missing executable: $p" >&2
    exit 1
  fi
}

need_file() {
  local p="$1"
  if [[ ! -e "$p" ]]; then
    echo "ERROR: missing file: $p" >&2
    exit 1
  fi
}

need_exec "$CLANG"
need_exec "$LD_LLD"
need_exec "$LLVM_AR"
need_exec "$LLVM_NM"
need_exec "$LLVM_OBJCOPY"
need_exec "$LLVM_OBJDUMP"
need_exec "$LLVM_STRIP"
need_exec "$AOSP_MAKE"
need_file "$KERNEL_DIR/scripts/gki/envsetup.sh"
need_file "$KERNEL_DIR/scripts/gki/generate_defconfig.sh"
need_file "$KERNEL_DIR/arch/arm64/configs/vendor/holi_QGKI.config"
need_file "$KERNEL_DIR/arch/arm64/configs/vendor/ext_config/moto-holi-penang.config"

mkdir -p "$KERNEL_OUT_DIR"

# ---------- exported env ----------
export ARCH=arm64
export TARGET_PRODUCT
export TARGET_BUILD_VARIANT
export KERN_OUT="$KERNEL_OUT_DIR"

export REAL_CC="$CLANG"
export HOSTCC="$CLANG"
export HOSTLD="$HOST_X86_LD"
export HOSTAR="$HOST_X86_AR"

export CROSS_COMPILE="$AARCH64_CROSS"
export CLANG_TRIPLE="aarch64-linux-gnu-"
export AR="$LLVM_AR"
export LLVM_NM="$LLVM_NM"
export LD="$LD_LLD"
export NM="$LLVM_NM"
export OBJCOPY="$LLVM_OBJCOPY"
export OBJDUMP="$LLVM_OBJDUMP"
export STRIP="$LLVM_STRIP"

# Prevent accidental fallback to host assembler/linker.
export PATH="$CLANG_DIR:$PATH"

# Motorola examples pass these explicitly.
export HOSTCFLAGS="-I$KERNEL_DIR/include/uapi -I/usr/include -I/usr/include/x86_64-linux-gnu -I$KERNEL_DIR/include -L/usr/lib -L/usr/lib/x86_64-linux-gnu -fuse-ld=lld"
export HOSTLDFLAGS="-L/usr/lib -L/usr/lib/x86_64-linux-gnu -fuse-ld=lld"

# Keep Motorola's build-time overlay knobs present.
export DTC_EXT="dtc"
export DTC_OVERLAY_TEST_EXT="ufdt_apply_overlay"
export CONFIG_BUILD_ARM64_DT_OVERLAY=y

echo "== Build settings =="
echo "REPO_ROOT=$REPO_ROOT"
echo "TARGET_PRODUCT=$TARGET_PRODUCT"
echo "TARGET_BUILD_VARIANT=$TARGET_BUILD_VARIANT"
echo "KERNEL_OUT_DIR=$KERNEL_OUT_DIR"
echo "REAL_CC=$REAL_CC"
echo "LD=$LD"
echo "CROSS_COMPILE=$CROSS_COMPILE"
echo

if [[ "$DO_CLEAN_OUT" == "1" ]]; then
  echo "== Cleaning out dir =="
  rm -rf "$KERNEL_OUT_DIR"
  mkdir -p "$KERNEL_OUT_DIR"
fi

echo "== Source envsetup =="
cd "$KERNEL_DIR"
# shellcheck disable=SC1091
source "$KERNEL_DIR/scripts/gki/envsetup.sh" holi

echo "== Generate defconfig =="
cd "$MY_TOP_DIR"
MAKE_PATH= \
ARCH="$ARCH" \
CROSS_COMPILE="$CROSS_COMPILE" \
REAL_CC="$REAL_CC" \
CLANG_TRIPLE="$CLANG_TRIPLE" \
AR="$AR" \
LLVM_NM="$LLVM_NM" \
LD="$LD" \
NM="$NM" \
OBJCOPY="$OBJCOPY" \
OBJDUMP="$OBJDUMP" \
STRIP="$STRIP" \
KERN_OUT="$KERNEL_OUT_DIR" \
DTC_EXT="$DTC_EXT" \
DTC_OVERLAY_TEST_EXT="$DTC_OVERLAY_TEST_EXT" \
CONFIG_BUILD_ARM64_DT_OVERLAY="$CONFIG_BUILD_ARM64_DT_OVERLAY" \
HOSTCC="$HOSTCC" \
HOSTAR="$HOSTAR" \
HOSTLD="$HOSTLD" \
TARGET_BUILD_VARIANT="$TARGET_BUILD_VARIANT" \
"$KERNEL_DIR/scripts/gki/generate_defconfig.sh" vendor/holi-qgki_defconfig

echo "== Verify Penang selection =="
grep '^CONFIG_PENANG_DTB=y$' "$KERNEL_DIR/arch/arm64/configs/vendor/holi-qgki_defconfig"

echo "== Expand full .config =="
"$AOSP_MAKE" -j"$JOBS" -C "$KERNEL_DIR" \
  O="$KERNEL_OUT_DIR" \
  REAL_CC="$REAL_CC" \
  CLANG_TRIPLE="$CLANG_TRIPLE" \
  AR="$AR" \
  LLVM_NM="$LLVM_NM" \
  LD="$LD" \
  NM="$NM" \
  OBJCOPY="$OBJCOPY" \
  OBJDUMP="$OBJDUMP" \
  STRIP="$STRIP" \
  DTC_EXT="$DTC_EXT" \
  DTC_OVERLAY_TEST_EXT="$DTC_OVERLAY_TEST_EXT" \
  CONFIG_BUILD_ARM64_DT_OVERLAY="$CONFIG_BUILD_ARM64_DT_OVERLAY" \
  HOSTCC="$HOSTCC" \
  HOSTAR="$HOSTAR" \
  HOSTLD="$HOSTLD" \
  HOSTCFLAGS="$HOSTCFLAGS" \
  HOSTLDFLAGS="$HOSTLDFLAGS" \
  ARCH="$ARCH" \
  CROSS_COMPILE="$CROSS_COMPILE" \
  LLVM_IAS=1 \
  vendor/holi-qgki_defconfig

"$AOSP_MAKE" -j"$JOBS" -C "$KERNEL_DIR" \
  O="$KERNEL_OUT_DIR" \
  REAL_CC="$REAL_CC" \
  CLANG_TRIPLE="$CLANG_TRIPLE" \
  AR="$AR" \
  LLVM_NM="$LLVM_NM" \
  LD="$LD" \
  NM="$NM" \
  OBJCOPY="$OBJCOPY" \
  OBJDUMP="$OBJDUMP" \
  STRIP="$STRIP" \
  DTC_EXT="$DTC_EXT" \
  DTC_OVERLAY_TEST_EXT="$DTC_OVERLAY_TEST_EXT" \
  CONFIG_BUILD_ARM64_DT_OVERLAY="$CONFIG_BUILD_ARM64_DT_OVERLAY" \
  HOSTCC="$HOSTCC" \
  HOSTAR="$HOSTAR" \
  HOSTLD="$HOSTLD" \
  HOSTCFLAGS="$HOSTCFLAGS" \
  HOSTLDFLAGS="$HOSTLDFLAGS" \
  ARCH="$ARCH" \
  CROSS_COMPILE="$CROSS_COMPILE" \
  LLVM_IAS=1 \
  olddefconfig

echo "== Main kernel build =="
"$AOSP_MAKE" -j"$JOBS" -C "$KERNEL_DIR" \
  O="$KERNEL_OUT_DIR" \
  REAL_CC="$REAL_CC" \
  CLANG_TRIPLE="$CLANG_TRIPLE" \
  AR="$AR" \
  LLVM_NM="$LLVM_NM" \
  LD="$LD" \
  NM="$NM" \
  OBJCOPY="$OBJCOPY" \
  OBJDUMP="$OBJDUMP" \
  STRIP="$STRIP" \
  DTC_EXT="$DTC_EXT" \
  DTC_OVERLAY_TEST_EXT="$DTC_OVERLAY_TEST_EXT" \
  CONFIG_BUILD_ARM64_DT_OVERLAY="$CONFIG_BUILD_ARM64_DT_OVERLAY" \
  HOSTCC="$HOSTCC" \
  HOSTAR="$HOSTAR" \
  HOSTLD="$HOSTLD" \
  HOSTCFLAGS="$HOSTCFLAGS" \
  HOSTLDFLAGS="$HOSTLDFLAGS" \
  ARCH="$ARCH" \
  CROSS_COMPILE="$CROSS_COMPILE" \
  LLVM_IAS=1 \
  Image

if [[ "$DO_HEADERS_INSTALL" == "1" ]]; then
  echo "== headers_install =="
  "$AOSP_MAKE" -j"$JOBS" -C "$KERNEL_DIR" \
    O="$KERNEL_OUT_DIR" \
    REAL_CC="$REAL_CC" \
    CLANG_TRIPLE="$CLANG_TRIPLE" \
    AR="$AR" \
    LLVM_NM="$LLVM_NM" \
    LD="$LD" \
    NM="$NM" \
    OBJCOPY="$OBJCOPY" \
    OBJDUMP="$OBJDUMP" \
    STRIP="$STRIP" \
    DTC_EXT="$DTC_EXT" \
    DTC_OVERLAY_TEST_EXT="$DTC_OVERLAY_TEST_EXT" \
    CONFIG_BUILD_ARM64_DT_OVERLAY="$CONFIG_BUILD_ARM64_DT_OVERLAY" \
    HOSTCC="$HOSTCC" \
    HOSTAR="$HOSTAR" \
    HOSTLD="$HOSTLD" \
    HOSTCFLAGS="$HOSTCFLAGS" \
    HOSTLDFLAGS="$HOSTLDFLAGS" \
    ARCH="$ARCH" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    LLVM_IAS=1 \
    headers_install
fi

if [[ "$DO_MODULES_INSTALL" == "1" ]]; then
  echo "== modules_install =="
  "$AOSP_MAKE" -j"$JOBS" -C "$KERNEL_DIR" \
    O="$KERNEL_OUT_DIR" \
    ARCH="$ARCH" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    INSTALL_MOD_STRIP=1 \
    INSTALL_MOD_PATH="$KERNEL_OUT_DIR/staging" \
    REAL_CC="$REAL_CC" \
    CLANG_TRIPLE="$CLANG_TRIPLE" \
    AR="$AR" \
    LLVM_NM="$LLVM_NM" \
    LD="$LD" \
    NM="$NM" \
    OBJCOPY="$OBJCOPY" \
    OBJDUMP="$OBJDUMP" \
    STRIP="$STRIP" \
    DTC_EXT="$DTC_EXT" \
    DTC_OVERLAY_TEST_EXT="$DTC_OVERLAY_TEST_EXT" \
    CONFIG_BUILD_ARM64_DT_OVERLAY="$CONFIG_BUILD_ARM64_DT_OVERLAY" \
    HOSTCC="$HOSTCC" \
    HOSTAR="$HOSTAR" \
    HOSTLD="$HOSTLD" \
    LLVM_IAS=1 \
    modules_install
fi

echo "== Artifacts =="
ls -lah "$KERNEL_OUT_DIR/arch/arm64/boot/Image" || true
if [[ -f "$KERNEL_OUT_DIR/arch/arm64/boot/Image" ]]; then
  gzip -c "$KERNEL_OUT_DIR/arch/arm64/boot/Image" > "$KERNEL_OUT_DIR/arch/arm64/boot/Image.gz"
  ls -lah "$KERNEL_OUT_DIR/arch/arm64/boot/Image.gz"
fi

echo "== Final config fingerprint =="
grep -E '^(CONFIG_ARCH_HOLI|CONFIG_PENANG_DTB|CONFIG_CC_VERSION_TEXT|CONFIG_LTO|CONFIG_THINLTO|CONFIG_MODULES|CONFIG_MODVERSIONS)=' \
  "$KERNEL_OUT_DIR/.config" || true

echo
echo "Build completed."
