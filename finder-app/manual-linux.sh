#!/bin/sh
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    # From slide: Building-the-Linux-Kernel.pdf
    make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- mrproper #“deep clean” the kernel build tree - removing the .config file with any existing configurations
    make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- defconfig #○ Configure for our “virt” arm dev board we will simulate in QEMU
    make -j4 ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- all # Build a kernel image for booting with QEMU
    #make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- modules # Build any kernel modules
    #Skip the modules_install step discussed in the video content.  The modules generated with the default kernel build are too large to fit in the initramfs with default memory. 
    make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- dtbs # Build the devicetree

fi

echo "Adding the Image in outdir"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
#from slide: Linux-Root-Filesystems.pptx.pdf
mkdir -p ${OUTDIR}/rootfs
mkdir -p ${OUTDIR}/rootfs/bin
mkdir -p ${OUTDIR}/rootfs/dev
mkdir -p ${OUTDIR}/rootfs/etc
mkdir -p ${OUTDIR}/rootfs/home
mkdir -p ${OUTDIR}/rootfs/lib
mkdir -p ${OUTDIR}/rootfs/lib64
mkdir -p ${OUTDIR}/rootfs/proc
mkdir -p ${OUTDIR}/rootfs/sbin
mkdir -p ${OUTDIR}/rootfs/sys
mkdir -p ${OUTDIR}/rootfs/tmp
mkdir -p ${OUTDIR}/rootfs/usr
mkdir -p ${OUTDIR}/rootfs/var
mkdir -p ${OUTDIR}/rootfs/usr/lib
mkdir -p ${OUTDIR}/rootfs/usr/bin
mkdir -p ${OUTDIR}/rootfs/usr/sbin
mkdir -p ${OUTDIR}/rootfs/var/log
#mkdir -p ${OUTDIR}/rootfs/dev/null


cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    # from slide: Linux-Root-Filesystems.pptx.pdf
    make distclean
    make defconfig
else
    cd busybox
fi

# TODO: Make and install busybox
#from slide: Linux-Root-Filesystems.pptx.pdf
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs  ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install


echo "Library dependencies"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
SYSROOT=$(aarch64-none-linux-gnu-gcc -print-sysroot) #in my case: /home/chris/linux1/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu/bin/../aarch64-none-linux-gnu/libc
echo "Sysroot is: ${SYSROOT}"
cp -a ${SYSROOT}/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib
cp -a ${SYSROOT}/lib64/libm.so.6 ${OUTDIR}/rootfs/lib64
cp -a ${SYSROOT}/lib64/libresolv.so.2 ${OUTDIR}/rootfs/lib64
cp -a ${SYSROOT}/lib64/libc.so.6 ${OUTDIR}/rootfs/lib64
echo "Done copying library dependencies"

# TODO: Make device nodes
cd ${OUTDIR}/
cd ./rootfs
ROOTFS=${OUTDIR}/rootfs
echo "ROOTFS is ${ROOTFS}"
sudo mknod -m 666 ${ROOTFS}/dev/null c 1 3
sudo mknod -m 600 ${ROOTFS}/dev/console c 5 1
echo "Done creating device nodes"

# TODO: Clean and build the writer utility
cd ${FINDER_APP_DIR}
echo "Finder app dir is: ${FINDER_APP_DIR}"
make clean
make CROSS_COMPILE=${CROSS_COMPILE}
echo "Done creating writer app"
cp writer ${OUTDIR}/rootfs/home/
echo "Done copying writer app to rootfs"

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cd ${OUTDIR}
cd ./rootfs
mkdir -p home/conf
cd ${FINDER_APP_DIR}
cp ./conf/username.txt ${OUTDIR}/rootfs/home/conf
cp ./conf/assignment.txt ${OUTDIR}/rootfs/home/conf
cp ./finder.sh ${OUTDIR}/rootfs/home
#cp ./writer.sh ${OUTDIR}/rootfs/home
cp ./finder-test.sh ${OUTDIR}/rootfs/home
cp ./autorun-qemu.sh ${OUTDIR}/rootfs/home

# TODO: Chown the root directory
cd ${OUTDIR}/
cd ./rootfs
sudo chown -R root:root ${OUTDIR}/rootfs

# TODO: Create initramfs.cpio.gz
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
cd ${OUTDIR}
gzip -f initramfs.cpio