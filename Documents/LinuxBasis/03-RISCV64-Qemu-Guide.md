# 03-RISCV64-Qemu-Guide

## 1. 目标
使用QEMU模拟器运行基于64位RISCV架构的Linux内核，并分别运行使用busybox引导的initramfs和使用systemd引导的rootfs

## 2. 配置环境
### 2.1 下载安装必要的工具和库
(1) 更新软件源
```bash
sudo apt update && sudo apt upgrade
```
(2) 安装基础软件
如果报错，可尝试重新更新软件源，然后再继续安装
```bash
sudo apt install git build-essential curl \
	python3 pip ninja-build \
	autoconf automake autotools-dev libtool \
	libmpc-dev libmpfr-dev libgmp-dev \
	libglib2.0-dev libpixman-1-dev libncurses5-dev libexpat-dev \
	zlib1g-dev libssl-dev libelf1 libelf-dev \
	gawk bison flex texinfo gperf patchutils bc
```
### 2.2 创建并进入工作目录
```bash
mkdir -p ${HOME}/riscv_oslab/{qemu,toolchain,kernel,busybox,initramfs,rootfs} 
```
```bash
cd ${HOME}/riscv_oslab
```
### 2.3 编译安装QEMU
#### 2.3.1 下载平头哥qemu仓库源码
```bash
cd qemu
```
```bash
git clone https://github.com/XUANTIE-RV/qemu.git qemu-master
```
#### 2.3.2 生成Makefile
(1) 初始化编译目录
```bash
sudo rm -rf build && mkdir build && cd build;
```
(2) 生成Makefile
```bash
${HOME}/riscv_oslab/qemu/qemu-master/configure --target-list=riscv64-softmmu,riscv64-linux-user
```
#### 2.3.3 编译安装qemu
```bash
make -j $(nproc) && sudo make install
```
#### 2.3.4 查看qemu版本
```bash
qemu-system-riscv64 --version
```
### 2.4 下载RISC-V GCC Toolchain
#### 2.4.1 下载工具链
```bash
cd ${HOME}/riscv_oslab/toolchain
```
```bash
wget https://github.com/XUANTIE-RV/xuantie-gnu-toolchain/releases/download/2023.03.21/riscv64-glibc-ubuntu-20.04-nightly-2023.03.21-nightly.tar.gz
```
#### 2.4.2 解压工具链
```bash
tar -xvzf riscv64-glibc-ubuntu-20.04-nightly-2023.03.21-nightly.tar.gz
```
#### 2.4.3 将工具链路径添加到环境变量
```bash
echo "export PATH=\${PATH}:\${HOME}/riscv_oslab/toolchain/riscv/bin" >> ~/.zshrc
```
```bash
source ~/.zshrc
```
#### 2.4.4 设置交叉编译环境变量
```bash
export ARCH=riscv && export CROSS_COMPILE=riscv64-unknown-linux-gnu-
```

## 3. 运行 kernel + initramfs(init with busybox)
### 3.1 下载并编译内核源码
#### 3.1.1 下载内核源码
```bash
cd ${HOME}/riscv_oslab/kernel
```
```bash
wget https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.10.4.tar.gz
```
#### 3.1.2 解压内核源码
```bash
tar -xzvf linux-5.10.4.tar.gz
```
#### 3.1.3 编译内核
(1) 初始化编译目录
```bash
rm -rf build && mkdir build && cd linux-5.10.4
```
(2) 触发编译
```bash
make defconfig O=${HOME}/riscv_oslab/kernel/build && make -j$(nproc) O=${HOME}/riscv_oslab/kernel/build
```
### 3.2 下载并编译busybox源码
#### 3.2.1 下载busybox源码
```bash
cd ${HOME}/riscv_oslab/busybox
```
```bash
wget https://busybox.net/downloads/busybox-1.33.1.tar.bz2
```
#### 3.2.2 解压busybox源码
```bash
tar -jxvf  busybox-1.33.1.tar.bz2
```
#### 3.2.3 编译busybox
(1) 初始化编译目录
```bash
rm -rf build && mkdir build && cd busybox-1.33.1
```
(2) 生成默认配置
```bash
make defconfig  O=${HOME}/riscv_oslab/busybox/build					
```
#### 3.2.4 设置static编译

1. 运行make menuconfig, 在界面中配置 “Build static binary”，路径如下，上下方向键移动光标，按空格键开启配置：
	Settings  --->
		--- Build Options
            [*] Build static binary (no shared libs)
2. 开启选项后，左右方向键移动光标到“exit”按钮，回车退出，根据提示保存配置到.config
3. 若需要长期保存配置，可将生成的.cofnig移动至src/configs/xxx_defconfig，
    下次编译时，可直接make xxx_defconfig使用相应配置。
4. make menuconfig具体命令如下：
```bash
make menuconfig O=${HOME}/riscv_oslab/busybox/build
```

#### 3.2.5
(1) 触发编译
```bash
make -j$(nproc) O=${HOME}/riscv_oslab/busybox/build
```
(2) 安装，默认安装到_build/_install目录
```bash
make install O=${HOME}/riscv_oslab/busybox/build
```

(3) 将busybox产物拷贝至initramfs目录，作为initramfs的目录基础
```bash
mv ${HOME}/riscv_oslab/busybox/build/_install ${HOME}/riscv_oslab/initramfs/busybox_rootfs
```
### 3.3 制作initramfs镜像
#### 3.3.1 创建根目录基础目录
```bash
cd ${HOME}/riscv_oslab/initramfs/busybox_rootfs
```
```bash
mkdir -p dev etc/init.d proc root sys
```
#### 3.3.2 创建fstab配置文件
```bash
# 生成fstab，默认挂载sys和proc目录
cat << EOF > etc/fstab
proc	/proc	proc	defaults	0	0
sysfs	/sys	sysfs	defaults	0	0
EOF
```
#### 3.3.3 创建rcS初始化文件
```bash
# 生成rcS文件
cat << EOF > etc/init.d/rcS
#!bin/sh
mount -a
/sbin/mdev -s
sleep 1
EOF

# 增加可执行权限
chmod +x etc/init.d/rcS
```
#### 3.3.4 创建console、ram字符设备文件
```bash
sudo mknod dev/console c 5 1
```
```bash
sudo mknod dev/ram b 1 0
```
#### 3.3.5 生成initramfs cpio镜像文件
```bash
cd ${HOME}/riscv_oslab/initramfs/busybox_rootfs 
```
```bash
find -print0 | cpio -0oH newc | gzip -9 > ../busybox_rootfs.img
```
### 3.4 检查生成的产物 
```bash
KERNEL_IMAGE=${HOME}/riscv_oslab/kernel/build/arch/riscv/boot/Image
```
```bash
INITRAMFS_IMAGE=${HOME}/riscv_oslab/initramfs/busybox_rootfs.img
```
### 3.5 使用qemu运行生成的linux内核和initramfs
```bash
qemu-system-riscv64 -nographic -machine virt -m 2048 \
        -kernel ${KERNEL_IMAGE} \
        -initrd ${INITRAMFS_IMAGE}  \
        -append "root=/dev/ram rdinit=/sbin/init"
```

## 4. 运行 kernel + rootfs(init with systemd)
### 4.1 制作rootfs镜像
#### 4.1.1 编译systemd、busybox等，制作根文件系统，保存至rootfs_raw
```bash
mkdir -p rootfs
具体操作待完善
```
#### 4.1.2 生成1GB镜像文件
```bash
dd if=/dev/zero of=systemd_rootfs_ext4.img bs=1M count=1024
```
#### 4.1.3 格式化为ext4文件系统
```bash
mkfs.ext4 systemd_rootfs_ext4.img
```
#### 4.1.4 挂载镜像文件，像镜像中拷贝实际文件系统数据
```bash
mkdir systemd_rootfs_ext4
```
```bash
sudo mount -o loop -t ext4 systemd_rootfs_ext4.img systemd_rootfs_ext4
```
```bash
sudo cp -rf rootfs/* systemd_rootfs_ext4/
```
```bash
sudo umount systemd_rootfs_ext4
```
### 4.2 使用qemu运行生成的linux内核和systemd
将systemd_rootfs_ext4.img镜像文件挂载为virtio-blk-device, id=0, name=vda
(1) 指定rootfs镜像文件路径
```bash
ROOTFS_IMAGE=${HOME}/riscv_oslab/rootfs/systemd_rootfs_ext4.img
```

(2) 启动虚拟机
```bash
qemu-system-riscv64 -nographic -machine virt -m 2048 \
					-kernel ${KERNEL_IMAGE}  \
					-append "root=/dev/vda rw rootfstype=ext4 rdinit=/lib/systemd/systemd" \
					-drive file=${ROOTFS_IMAGE},format=raw,id=drive0 \
					-device virtio-blk-device,drive=drive0
```

### 4.3 添加QEMU虚拟网卡，使虚拟机连接到网络
在qemu内创建虚拟网卡，并将其桥接到外部网络，使得可以从物理机通过网络访问qemu虚拟机
#### 4.3.1 创建网桥连接
(1) 安装bridge-utils工具
```bash
sudo apt update -y && sudo apt install -y bridge-utils
```
(2) 创建网桥接口br0
```bash
sudo brctl addbr br0
```
(3) 设置网桥ip
```bash
sudo ip addr add 172.16.202.129/24 broadcast 172.16.202.255 dev br0
```
(4) 启用网桥br0
```bash
sudo ip link set dev br0 up
```
(5) 设置默认路由
172.16.202.2为VMWare NAT网络的网关地址，具体可从VMWare网络配置中查看，具体路径如下：
编辑 --> 虚拟网络编辑器 --> NAT 设置(需鼠标选中VMnet8 NAT 模式网络)--> 网关
```bash
sudo ip route add default via 172.16.202.2 dev br0
```
(6) 将ens33网卡桥接到网桥br0
```bash
sudo brctl addif br0 ens33
```
(7) 查看当前所有网络连接
```bash
nmcli connection show
```
(8) 将原有线连接的默认自动连接选项关闭
```bash
nmcli connection modify ens33 connection.autoconnect no
```
(9) 断开有线连接
```bash
nmcli connection down ens33
```
(10) 设置网桥自动连接
```bash
nmcli connection modify br0 connection.autoconnect yes
```
(11) 启用网桥连接
```bash
nmcli connection up br0
```
#### 4.3.2 创建虚拟网卡, 并将其连接到网桥
(1) 加载tap驱动
```bash
sudo modprobe tap
```
(2) 创建tap0虚拟网卡
```bash
sudo ip tuntap add dev tap0 mode tap
```
(3) 将tap0虚拟网卡桥接到网桥br0
```bash
sudo brctl addif br0 tap0
```
(4) 启用虚拟网卡tap0
```bash
sudo ip link set dev tap0 up
```
(5) 进入qemu虚拟机，设置网卡ip
```bash
ifconfig eth0 172.16.202.131 netmask 255.255.255.0
```
(6) ping物理机，网络已经连通
```bash
ping 172.16.202.129
```
(7) 物理机pingqemu虚拟机，网络连通
```bash
ping 172.16.202.131
```
#### 4.3.3 启动带有虚拟网卡的QEMU虚拟机
```bash
qemu-system-riscv64 -nographic -machine virt -m 2048 \
	-kernel ${KERNEL_IMAGE} \
	-append "root=/dev/vda rw rootfstype=ext4 rdinit=/lib/systemd/systemd" \
	-device virtio-blk-device,drive=drive0 \
	-drive file=${ROOTFS_IMAGE},format=raw,id=drive0 \
	-device virtio-net-device,netdev=net0 \
	-netdev tap,id=net0,ifname=tap0,script=no,downscript=no
```

