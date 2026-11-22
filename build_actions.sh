#!/bin/bash
# Builds ONLY the SukiSU kernel. Scripts come from YOUR fork (build-actions branch).

set -x

# GITHUB_REPOSITORY is filled in automatically by GitHub (e.g. yourname/valeryn_xiaomi_sm6115)
curl -o build_sukisu.sh -L "https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/refs/heads/build-actions/build_sukisu.sh" || exit 1

mkdir build
cd build
rm -rf kernel
git clone https://github.com/Joe7500/valeryn_xiaomi_sm6115 kernel

cd kernel || exit 1
KERNEL_BUILD_DIR=`pwd`
cd ../../
ln -s "$KERNEL_BUILD_DIR"/.git .git
cd build/kernel || exit 1

git config user.email "user@localhost"
git config user.name "user"

# sukisu
rm -rf *
git reset --hard
git switch android16
git switch -c build-sukisu || exit 1
bash ../../build_sukisu.sh
if [ $? -eq 0 ] ; then
   cp 4.19*.zip ../../
else
   echo FAILED
   exit 1
fi

exit 0
