#!/bin/bash
# SukiSU (builtin branch) build for Valeryn 4.19 (SM6115) -- v2
# Based on Joe7500's build_ksun1.sh (same toolchain + AnyKernel3 packaging).
# v2: NO manual hook commits. Uses SukiSU's CONFIG_KSU_HACK_ARM64_BRANCH_LINK
#     (recommended by the SukiSU docs for 4.19+ ARM64). SUSFS is OFF for now.

DEFCONFIG="vendor/bengal-perf_defconfig"
ZIPNAME=4.19-A16-valeryn-sukisu-`date +'%d.%m.%y-%H%M'`.zip

set -x

# Setup tools
curl -o toolchain.tar.xz -L https://github.com/Joe7500/Builds/releases/download/Stuff/toolchain.tar.xz || exit 1
curl -o AnyKernel3.tar.xz -L https://github.com/Joe7500/Builds/releases/download/Stuff/AnyKernel3.tar.xz || exit 1
rm -rf toolchain prebuilts
tar xf toolchain.tar.xz || exit 1
ln -s prebuilts/clang/host/linux-x86/clang-stablekern/ toolchain
tar xf AnyKernel3.tar.xz || exit 1
PATH=$PWD/toolchain/bin:$PATH

# Only the path_umount backport (SukiSU's umount code can use it)
git cherry-pick 9ddea125151ce61abbd05a84e8de72f8fc45da57 || exit 1

# Add SukiSU "builtin" branch. Official source first, GitHub mirror as fallback.
curl -fLSs "https://git.zako.shirkneko.top:20004/shirkneko/SukiSU/raw/branch/main/kernel/setup.sh" -o setup.sh \
  || curl -fLSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" -o setup.sh \
  || exit 1
bash setup.sh builtin || exit 1

# --- 4.19 compatibility fixes (these headers only exist on 5.10+ kernels) ---
grep -rl "linux/static_call.h" drivers/kernelsu/ | xargs -r sed -i 's|#include <linux/static_call.h>|/* disabled for 4.19 */|'
grep -rl "linux/hex.h" drivers/kernelsu/ | xargs -r sed -i 's|<linux/hex.h>|<linux/kernel.h>|'
grep -rl "uapi/linux/mount.h" drivers/kernelsu/ | xargs -r sed -i 's|<uapi/linux/mount.h>|<linux/fs.h>|'
# show whether the code really uses static_call (for debugging)
grep -rn "static_call" drivers/kernelsu/ || true

# KSU_NO_PREINIT is also defined on the compiler command line -> guard the define
sed -i 's|^#define KSU_NO_PREINIT[[:space:]]*$|#ifndef KSU_NO_PREINIT\n#define KSU_NO_PREINIT\n#endif|' drivers/kernelsu/preinit/common/preinit.h
# 4.19 access_ok() takes 3 arguments (type, addr, size)
grep -rl "access_ok(" drivers/kernelsu/ | xargs -r sed -i 's/access_ok(\([^V]\)/access_ok(VERIFY_READ, \1/g'
# harmless warnings (e.g. unused variables) must not stop the build
echo 'ccflags-y += -Wno-error' >> drivers/kernelsu/Makefile

# Kernel config
echo "CONFIG_KSU=y" >> arch/arm64/configs/vendor/bengal-perf_defconfig
echo "CONFIG_KALLSYMS=y" >> arch/arm64/configs/vendor/bengal-perf_defconfig
echo "CONFIG_KSU_HACK_ARM64_BRANCH_LINK=y" >> arch/arm64/configs/vendor/bengal-perf_defconfig
echo "# CONFIG_KSU_SUSFS is not set" >> arch/arm64/configs/vendor/bengal-perf_defconfig

echo "-perf" > localversion

# Build it
rm -rf out/
mkdir out/
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 $DEFCONFIG
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 -j$(nproc) || {
  echo "=== BUILD FAILED: re-running single-threaded to show the real error ==="
  make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 -j1 2>&1 | tail -n 60
  exit 1
}
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 -j$(nproc) Image.gz || exit 1
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 -j$(nproc) dtbs || exit 1

# Make anykernel package
kernel="out/arch/arm64/boot/Image.gz"
dtbo="out/arch/arm64/boot/dtbo.img"
dtb="out/arch/arm64/boot/dtb.img"

cp "out/arch/arm64/boot/dtb" "out/arch/arm64/boot/dtb.img"

cp $kernel AnyKernel3
cp $dtbo AnyKernel3
cp $dtb AnyKernel3

cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x .git *placeholder
cd ..
