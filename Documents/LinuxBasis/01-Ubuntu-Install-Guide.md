# 01-Ubuntu Install Guide

## 1. 设置root密码并切换至root
```bash
sudo passwd root && su
```

## 2. 更新软件
```bash
apt update && apt upgrade -y 
```

## 3. 安装基础常用软件
```bash
apt install -y vim git python3 pip build-essential curl wget net-tools iputils-ping
```

## 4. 配置ssh
### 4.1 安装openssh
```bash
apt install -y openssh-server openssh-client
```
### 4.2 ssh配置文件修改
```bash
sudo vim /etc/ssh/sshd_config
```
#### 4.2.1 密码登录
```bash
# 设置密码登录
PasswordAuthentication yes
```
#### 4.2.2 root登录
```bash
# 允许root登录
PermitRootLogin yes
```
### 4.3 重启sshd服务
```bash
sudo systemctl restart sshd
```

## 5. 配置samba
### 5.1 安装samba
```bash
sudo apt install -y samba
```
### 5.2 修改samba配置
```bash
sudo vim /etc/samba/smb.conf
```
#### 5.2.1 配置wanguo共享目录
```bash
[wanguo]
comment = samba share path
browseable = yes
path = /home/wanguo
create mask = 0700
directory mask = 0700
valid users = wanguo
force user = wanguo
force group = wanguo
public = yes
available = yes
writable = yes
```
### 5.3 添加samba用户
执行如下命令，并根据提示设置密码
```bash
sudo smbpasswd -a wanguo
```
### 5.4 重启smbd服务
```bash
sudo systemctl restart smbd
```

## 6 安装zsh && oh-my-zsh
### 6.1 安装zsh
```bash
apt install -y zsh
```
### 6.2 下载并安装oh-my-zsh
```bash
sh -c "$(curl -fsSL https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh)"
```
### 6.3 安装插件
(1) 命令高亮
```bash
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```
(2) 命令提示
```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```
(3) 命令补全
```bash
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions
```
### 6.4 配置zshrc
```bash
vim ~/.zshrc
```
#### 6.4.1 修改主题
```bash
ZSH_THEME="jonathan"
```
#### 6.4.2 开启插件
```bash
plugins=(git
z
sudo 
extract 
zsh-autosuggestions 
zsh-syntax-highlighting
zsh-completions
)
```
#### 6.4.3 设置常用alias
```bash
alias cls='clear'
alias cp='cp -rf'
alias rf='rm -rf'
alias grepc='find . -iname "*.c" | xargs grep -rn --color=auto '
alias greph='find . -iname "*.h" | xargs grep -rn --color=auto '
```

## 7. 搭建nfs服务器
### 7.1 安装nfs-server
```bash
sudo apt install nfs-kernel-server
```
### 7.2 创建nfs目录
```bash
mkdir -p ${HOME}/nfs && chmod 777 ${HOME}/nfs
```
### 7.3 配置nfs目录
```bash
sudo echo "${HOME}/nfs *(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports
```
### 7.4 重启nfs服务
```bash
sudo systemctl restart nfs-kernel-server
```
### 7.5 查看nfs目录是否导出成功
```bash
showmount -e
```
### 7.6 查看nfs目录是否可以正常挂载
挂载nfs目录并创建文件，若能挂载成功，且在nfs目录下看到测试文件生成，则说明功能正常
```bash
# 创建临时目录并将其挂载到nfs目录
mkdir ${HOME}/nfs_test && sudo mount -t nfs 127.0.0.1:${HOME}/nfs ${HOME}/nfs_test
```
```bash
# 在挂载目录内创建测试文件
touch ${HOME}/nfs_test/test_file
```
```bash
# 卸载nfs目录
sudo umount ${HOME}/nfs_test
```
```bash
# 查看nfs目录下是否生成了测试文件
ls -l ${HOME}/nfs/test_file
```


## 8. 搭建tftp服务器
### 8.1 安装tftpd-hpa
```
sudo apt update
sudo apt install tftpd-hpa
```
### 8.2 配置tftp
打开配置文件
```
sudo vim /etc/default/tftpd-hpa
```
``` shell
# /etc/default/tftpd-hpa

TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/home/wanguo/99-tftp"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure -l -c"
```
### 8.3 重启TFTP服务以应用更改
```
sudo systemctl restart tftpd-hpa
```


