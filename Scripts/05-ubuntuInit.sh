#!/bin/bash

#############################################
# Ubuntu 开发环境自动部署脚本
# 基于: 01-Ubuntu-Install-Guide.md
# 功能: 全自动部署开发环境，支持断点续传
#############################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 检查是否以root权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 sudo 运行此脚本"
        exit 1
    fi
}

# 获取实际用户名（即使使用sudo）
get_real_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}

REAL_USER=$(get_real_user)
REAL_HOME=$(eval echo ~$REAL_USER)

log_info "实际用户: $REAL_USER"
log_info "用户主目录: $REAL_HOME"

#############################################
# 1. 配置APT镜像源
#############################################
configure_apt_source() {
    log_info "配置APT镜像源..."

    read -p "是否自动选择最快的APT镜像源？(y/n): " change_source
    if [ "$change_source" != "y" ]; then
        log_info "跳过APT镜像源配置"
        return 0
    fi

    # 获取Ubuntu版本
    local ubuntu_version=$(lsb_release -rs)
    local ubuntu_codename=$(lsb_release -cs)

    log_info "检测到Ubuntu版本: ${ubuntu_version} (${ubuntu_codename})"

    # 备份原sources.list
    local sources_file="/etc/apt/sources.list"
    if [ ! -f "${sources_file}.bak" ]; then
        cp "$sources_file" "${sources_file}.bak"
        log_info "已备份原APT源配置: ${sources_file}.bak"
    fi

    # 检查是否安装了python3和pip
    if ! command -v pip3 &> /dev/null; then
        log_info "安装 python3-pip..."
        apt update -y
        apt install -y python3-pip
    fi

    # 安装apt-select
    if ! command -v apt-select &> /dev/null; then
        log_info "安装 apt-select..."
        pip3 install apt-select
    else
        log_info "apt-select 已安装"
    fi

    # 使用apt-select自动选择最快的镜像源
    log_info "正在测试并选择最快的镜像源（这可能需要几分钟）..."

    # apt-select会自动测试所有可用镜像源并选择最快的
    # -C 指定国家（CN=中国）
    # -t 指定测试的镜像源数量
    if apt-select -C CN -t 5 -m one-week-behind; then
        log_success "镜像源测试完成"

        # apt-select会生成sources.list文件
        if [ -f "sources.list" ]; then
            mv sources.list "$sources_file"
            log_success "APT源配置完成"
        else
            log_error "apt-select未生成配置文件"
            return 1
        fi
    else
        log_error "apt-select执行失败，保持原配置"
        return 1
    fi

    # 更新软件包列表
    log_info "更新软件包列表..."
    if apt update -y; then
        log_success "软件包列表更新成功"
    else
        log_error "软件包列表更新失败，恢复原配置..."
        cp "${sources_file}.bak" "$sources_file"
        apt update -y
        return 1
    fi
}

#############################################
# 2. 更新系统软件包
#############################################
update_system() {
    log_info "开始更新系统软件包..."

    if apt update -y && apt upgrade -y; then
        log_success "系统软件包更新完成"
        return 0
    else
        log_error "系统软件包更新失败"
        return 1
    fi
}

#############################################
# 3. 安装基础软件
#############################################
install_basic_packages() {
    log_info "检查并安装基础软件包..."

    local packages=(
        "vim" "git" "python3" "python3-pip" "build-essential"
        "curl" "wget" "net-tools" "iputils-ping" "libssl-dev"
        "libgnutls28-dev" "uuid-dev" "libncurses-dev" "tree"
        "unzip" "rsync"
    )

    local to_install=()

    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            to_install+=("$pkg")
        else
            log_info "$pkg 已安装，跳过"
        fi
    done

    if [ ${#to_install[@]} -gt 0 ]; then
        log_info "安装软件包: ${to_install[*]}"
        if apt install -y "${to_install[@]}"; then
            log_success "基础软件包安装完成"
        else
            log_error "基础软件包安装失败"
            return 1
        fi
    else
        log_success "所有基础软件包已安装"
    fi
}

#############################################
# 4. 配置时区
#############################################
configure_timezone() {
    log_info "配置时区为 Asia/Shanghai..."

    local current_tz=$(timedatectl show --property=Timezone --value)

    if [ "$current_tz" = "Asia/Shanghai" ]; then
        log_info "时区已设置为 Asia/Shanghai，跳过"
        return 0
    fi

    if timedatectl set-timezone Asia/Shanghai; then
        log_success "时区配置完成"
    else
        log_error "时区配置失败"
        return 1
    fi
}

#############################################
# 5. 配置SSH
#############################################
configure_ssh() {
    log_info "配置SSH服务..."

    # 检查是否已安装
    if ! dpkg -l | grep -q "^ii  openssh-server "; then
        log_info "安装 openssh-server..."
        apt install -y openssh-server openssh-client
    else
        log_info "openssh-server 已安装"
    fi

    # 备份原配置文件
    if [ ! -f /etc/ssh/sshd_config.bak ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
        log_info "已备份SSH配置文件"
    fi

    # 配置密码登录
    if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
        log_info "SSH密码登录已启用"
    else
        sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
        log_info "已启用SSH密码登录"
    fi

    # 配置root登录（可选，根据安全需求决定）
    read -p "是否允许root用户SSH登录？(不推荐，输入yes启用): " enable_root_login
    if [ "$enable_root_login" = "yes" ]; then
        sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
        log_warn "已启用root SSH登录（存在安全风险）"
    else
        log_info "保持root SSH登录禁用状态"
    fi

    # 重启SSH服务
    if systemctl restart sshd; then
        log_success "SSH服务配置完成并已重启"
    else
        log_error "SSH服务重启失败"
        return 1
    fi
}

#############################################
# 6. 配置Samba
#############################################
configure_samba() {
    log_info "配置Samba服务..."

    read -p "是否安装配置Samba？(y/n): " install_samba
    if [ "$install_samba" != "y" ]; then
        log_info "跳过Samba配置"
        return 0
    fi

    # 检查是否已安装
    if ! dpkg -l | grep -q "^ii  samba "; then
        log_info "安装 samba..."
        apt install -y samba
    else
        log_info "samba 已安装"
    fi

    # 检查配置是否已存在
    if grep -q "\[${REAL_USER}\]" /etc/samba/smb.conf; then
        log_info "Samba配置已存在，跳过"
    else
        # 备份配置文件
        if [ ! -f /etc/samba/smb.conf.bak ]; then
            cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
            log_info "已备份Samba配置文件"
        fi

        # 添加共享配置
        cat >> /etc/samba/smb.conf <<EOF

[${REAL_USER}]
comment = samba share path
browseable = yes
path = ${REAL_HOME}
create mask = 0700
directory mask = 0700
valid users = ${REAL_USER}
force user = ${REAL_USER}
force group = ${REAL_USER}
available = yes
writable = yes
EOF
        log_info "已添加Samba共享配置"
    fi

    # 检查Samba用户是否已存在
    if pdbedit -L | grep -q "^${REAL_USER}:"; then
        log_info "Samba用户 ${REAL_USER} 已存在"
    else
        log_info "添加Samba用户 ${REAL_USER}"
        echo -e "请输入Samba密码:"
        smbpasswd -a ${REAL_USER}
    fi

    # 重启Samba服务
    if systemctl restart smbd; then
        log_success "Samba服务配置完成并已重启"
    else
        log_error "Samba服务重启失败"
        return 1
    fi
}

#############################################
# 7. 安装配置Zsh和Oh-My-Zsh
#############################################
install_zsh() {
    log_info "安装配置Zsh和Oh-My-Zsh..."

    # 检查zsh是否已安装
    if ! command -v zsh &> /dev/null; then
        log_info "安装 zsh..."
        apt install -y zsh
    else
        log_info "zsh 已安装"
    fi

    # 检查oh-my-zsh是否已安装
    if [ -d "${REAL_HOME}/.oh-my-zsh" ]; then
        log_info "oh-my-zsh 已安装，跳过"
    else
        log_info "安装 oh-my-zsh..."
        # 以实际用户身份安装
        su - ${REAL_USER} -c 'sh -c "$(curl -fsSL https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh)" "" --unattended'
        log_success "oh-my-zsh 安装完成"
    fi

    # 安装插件
    local plugin_dir="${REAL_HOME}/.oh-my-zsh/custom/plugins"

    # zsh-syntax-highlighting
    if [ -d "${plugin_dir}/zsh-syntax-highlighting" ]; then
        log_info "zsh-syntax-highlighting 已安装"
    else
        log_info "安装 zsh-syntax-highlighting..."
        su - ${REAL_USER} -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${plugin_dir}/zsh-syntax-highlighting"
    fi

    # zsh-autosuggestions
    if [ -d "${plugin_dir}/zsh-autosuggestions" ]; then
        log_info "zsh-autosuggestions 已安装"
    else
        log_info "安装 zsh-autosuggestions..."
        su - ${REAL_USER} -c "git clone https://github.com/zsh-users/zsh-autosuggestions ${plugin_dir}/zsh-autosuggestions"
    fi

    # zsh-completions
    if [ -d "${plugin_dir}/zsh-completions" ]; then
        log_info "zsh-completions 已安装"
    else
        log_info "安装 zsh-completions..."
        su - ${REAL_USER} -c "git clone https://github.com/zsh-users/zsh-completions ${plugin_dir}/zsh-completions"
    fi

    # 配置.zshrc
    local zshrc="${REAL_HOME}/.zshrc"

    if [ -f "$zshrc" ]; then
        # 备份原配置
        if [ ! -f "${zshrc}.bak" ]; then
            cp "$zshrc" "${zshrc}.bak"
            log_info "已备份 .zshrc"
        fi

        # 修改主题
        if grep -q '^ZSH_THEME="jonathan"' "$zshrc"; then
            log_info "主题已设置为 jonathan"
        else
            sed -i 's/^ZSH_THEME=.*/ZSH_THEME="jonathan"/' "$zshrc"
            log_info "已设置主题为 jonathan"
        fi

        # 配置插件
        if grep -q 'zsh-syntax-highlighting' "$zshrc"; then
            log_info "插件配置已存在"
        else
            sed -i 's/^plugins=.*/plugins=(git z sudo extract zsh-autosuggestions zsh-syntax-highlighting zsh-completions)/' "$zshrc"
            log_info "已配置插件"
        fi

        # 添加alias
        if grep -q "alias grepc=" "$zshrc"; then
            log_info "自定义alias已存在"
        else
            cat >> "$zshrc" <<'EOF'

# Custom aliases
alias cls='clear'
alias cp='cp -rf'
alias rf='rm -rf'
alias grepc='find . -iname "*.c" | xargs grep -rn --color=auto '
alias greph='find . -iname "*.h" | xargs grep -rn --color=auto '
EOF
            log_info "已添加自定义alias"
        fi

        chown ${REAL_USER}:${REAL_USER} "$zshrc"
    fi

    # 设置zsh为默认shell
    if [ "$SHELL" = "$(which zsh)" ]; then
        log_info "zsh 已是默认shell"
    else
        log_info "设置zsh为默认shell..."
        chsh -s $(which zsh) ${REAL_USER}
        log_success "已设置zsh为默认shell（需重新登录生效）"
    fi

    log_success "Zsh配置完成"
}

#############################################
# 8. 配置NFS服务器
#############################################
configure_nfs() {
    log_info "配置NFS服务器..."

    read -p "是否安装配置NFS服务器？(y/n): " install_nfs
    if [ "$install_nfs" != "y" ]; then
        log_info "跳过NFS配置"
        return 0
    fi

    # 检查是否已安装
    if ! dpkg -l | grep -q "^ii  nfs-kernel-server "; then
        log_info "安装 nfs-kernel-server..."
        apt install -y nfs-kernel-server
    else
        log_info "nfs-kernel-server 已安装"
    fi

    # 创建NFS目录
    local nfs_dir="${REAL_HOME}/nfs"
    if [ ! -d "$nfs_dir" ]; then
        mkdir -p "$nfs_dir"
        chmod 777 "$nfs_dir"
        chown ${REAL_USER}:${REAL_USER} "$nfs_dir"
        log_info "已创建NFS目录: $nfs_dir"
    else
        log_info "NFS目录已存在: $nfs_dir"
    fi

    # 配置exports
    if grep -q "$nfs_dir" /etc/exports; then
        log_info "NFS导出配置已存在"
    else
        echo "${nfs_dir} *(rw,sync,no_root_squash,no_subtree_check)" | tee -a /etc/exports > /dev/null
        log_info "已添加NFS导出配置"
    fi

    # 重启NFS服务
    if systemctl restart nfs-kernel-server; then
        log_success "NFS服务配置完成并已重启"

        # 验证导出
        log_info "NFS导出列表:"
        showmount -e
    else
        log_error "NFS服务重启失败"
        return 1
    fi
}

#############################################
# 9. 配置TFTP服务器
#############################################
configure_tftp() {
    log_info "配置TFTP服务器..."

    read -p "是否安装配置TFTP服务器？(y/n): " install_tftp
    if [ "$install_tftp" != "y" ]; then
        log_info "跳过TFTP配置"
        return 0
    fi

    # 检查是否已安装
    if ! dpkg -l | grep -q "^ii  tftpd-hpa "; then
        log_info "安装 tftpd-hpa..."
        apt update -y
        apt install -y tftpd-hpa
    else
        log_info "tftpd-hpa 已安装"
    fi

    # 创建TFTP目录
    local tftp_dir="${REAL_HOME}/tftp"
    if [ ! -d "$tftp_dir" ]; then
        mkdir -p "$tftp_dir"
        chmod 777 "$tftp_dir"
        chown ${REAL_USER}:${REAL_USER} "$tftp_dir"
        log_info "已创建TFTP目录: $tftp_dir"
    else
        log_info "TFTP目录已存在: $tftp_dir"
    fi

    # 配置TFTP
    local tftp_config="/etc/default/tftpd-hpa"
    if [ -f "$tftp_config" ]; then
        # 备份配置
        if [ ! -f "${tftp_config}.bak" ]; then
            cp "$tftp_config" "${tftp_config}.bak"
            log_info "已备份TFTP配置文件"
        fi

        # 修改配置
        cat > "$tftp_config" <<EOF
# /etc/default/tftpd-hpa

TFTP_USERNAME="tftp"
TFTP_DIRECTORY="${tftp_dir}"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure -l -c"
EOF
        log_info "已更新TFTP配置"
    fi

    # 重启TFTP服务
    if systemctl restart tftpd-hpa; then
        log_success "TFTP服务配置完成并已重启"

        # 验证服务状态
        if systemctl is-active --quiet tftpd-hpa; then
            log_success "TFTP服务运行正常"
        else
            log_error "TFTP服务未正常运行"
            return 1
        fi
    else
        log_error "TFTP服务重启失败"
        return 1
    fi
}

#############################################
# 10. 配置Git
#############################################
configure_git() {
    log_info "配置Git..."

    read -p "是否配置Git用户信息？(y/n): " config_git
    if [ "$config_git" != "y" ]; then
        log_info "跳过Git配置"
        return 0
    fi

    # 获取用户输入
    read -p "请输入Git用户名: " git_username
    read -p "请输入Git邮箱: " git_email

    # 配置Git
    su - ${REAL_USER} -c "git config --global user.name '${git_username}'"
    su - ${REAL_USER} -c "git config --global user.email '${git_email}'"

    # 配置oh-my-zsh性能优化
    su - ${REAL_USER} -c "git config --global oh-my-zsh.hide-dirty 1"
    su - ${REAL_USER} -c "git config --global oh-my-zsh.hide-status 1"

    log_success "Git配置完成"

    # 询问是否配置代理
    read -p "是否配置Git代理？(y/n): " config_proxy
    if [ "$config_proxy" = "y" ]; then
        read -p "请输入代理地址 (例如: 192.168.100.1:7897): " proxy_addr
        su - ${REAL_USER} -c "git config --global http.proxy ${proxy_addr}"
        su - ${REAL_USER} -c "git config --global https.proxy ${proxy_addr}"
        log_success "Git代理配置完成"
    fi
}

#############################################
# 主函数
#############################################
main() {
    log_info "=========================================="
    log_info "Ubuntu 开发环境自动部署脚本"
    log_info "=========================================="

    # 检查root权限
    check_root

    # 执行各项配置
    configure_apt_source || log_error "APT源配置失败，继续执行..."

    update_system || log_error "系统更新失败，继续执行..."

    install_basic_packages || log_error "基础软件安装失败，继续执行..."

    configure_timezone || log_error "时区配置失败，继续执行..."

    configure_ssh || log_error "SSH配置失败，继续执行..."

    configure_samba || log_error "Samba配置失败，继续执行..."

    install_zsh || log_error "Zsh安装失败，继续执行..."

    configure_nfs || log_error "NFS配置失败，继续执行..."

    configure_tftp || log_error "TFTP配置失败，继续执行..."

    configure_git || log_error "Git配置失败，继续执行..."

    log_info "=========================================="
    log_success "所有配置任务已完成！"
    log_info "=========================================="
    log_info "提示:"
    log_info "1. 请重新登录以使Zsh生效"
    log_info "2. 如需使用Docker，请参考04-Docker-Install-Guide.md"
    log_info "3. 配置备份文件已保存（*.bak）"
    log_info "=========================================="
}

# 执行主函数
main "$@"
