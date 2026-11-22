#!/bin/bash
# SukiSU-Ultra (builtin / manual hooks) build for Valeryn 4.19 (SM6115)
# Based on Joe7500's build_ksun1.sh -- same toolchain, same 3 patch commits.

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

# Apply changes (path_umount backport, SusFS 1.5.12 backport, manual hooks)
git cherry-pick 9ddea125151ce61abbd05a84e8de72f8fc45da57 || exit 1
git cherry-pick f0b967626c361d95969dd962cd22dffe1ebe510d || exit 1
git cherry-pick dbc26ce49d11c5d1293dedb5f647dcdacf4432dd
grep -vE '<<<|===|>>>' arch/arm64/configs/vendor/bengal-perf_defconfig > arch/arm64/configs/vendor/bengal-perf_defconfig.1
mv arch/arm64/configs/vendor/bengal-perf_defconfig.1 arch/arm64/configs/vendor/bengal-perf_defconfig
git add arch/arm64/configs/vendor/bengal-perf_defconfig
git cherry-pick --continue --no-edit

# Add SukiSU-Ultra (builtin branch = manual hooks, no kprobes)
curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s builtin || exit 1

# Stage 1: root only, SUSFS switched OFF (add SUSFS later once this boots)
echo "CONFIG_KSU=y" >> arch/arm64/configs/vendor/bengal-perf_defconfig
echo "CONFIG_KSU_MANUAL_HOOK=y" >> arch/arm64/configs/vendor/bengal-perf_defconfig
echo "# CONFIG_KPROBES is not set" >> arch/arm64/configs/vendor/bengal-perf_defconfig
echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> arch/arm64/configs/vendor/bengal-perf_defconfig
echo "# CONFIG_KSU_SUSFS is not set" >> arch/arm64/configs/vendor/bengal-perf_defconfig

echo "-perf" > localversion

# Build it
rm -rf out/
mkdir out/
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 $DEFCONFIG
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 -j$(nproc) || exit 1
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
