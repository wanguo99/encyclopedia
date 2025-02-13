# 使用官方Ubuntu最新镜像作为基础镜像
FROM ubuntu:latest

# 设置环境变量，避免交互式配置提示
ENV DEBIAN_FRONTEND=noninteractive

# 更新软件包列表
RUN apt update -y && apt upgrade -y

# 安装必要的软件包
RUN apt install -y --no-install-recommends \
    build-essential \
    gcc-arm-linux-gnueabihf \
    gdb \
    git \
    zsh \
    curl \
    vim \
    sudo \
    python3 \
    python3-pip \
    wget \
    net-tools \
    iputils-ping \
    libssl-dev \
    libgnutls28-dev \
    uuid-dev \
    libncurses-dev \
    tree \
    unzip \
    bc \
    bison \
    flex \
    libelf-dev \
    ccache \
    dwarves \
    cscope \
    exuberant-ctags \
    clang \
    llvm \
    openssh-server \
    samba \
    nfs-kernel-server \
    tftpd-hpa \
    && rm -rf /var/lib/apt/lists/*

# 设置root密码并创建新用户wanguo，并设置密码
RUN echo "root:root_password" | chpasswd && \
    useradd -m wanguo && echo "wanguo:p" | chpasswd

# 创建挂载点目录
RUN mkdir -p /home/wanguo/HostMount && \
    chown -R wanguo:wanguo /home/wanguo/HostMount

# 切换到新创建的用户
USER wanguo

# 设置工作目录
WORKDIR /home/wanguo

# 安装zsh && oh-my-zsh
RUN sh -c "$(curl -fsSL https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh)"

# 安装命令行高亮插件
RUN git clone https://github.com/zsh-users/zsh-syntax-highlighting.git  \
                ${ZSH_CUSTOM:=$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# 安装命令提示插件
RUN git clone https://github.com/zsh-users/zsh-autosuggestions  \
                ${ZSH_CUSTOM:=$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# 安装命令补全插件
RUN git clone https://github.com/zsh-users/zsh-completions \
                ${ZSH_CUSTOM:=$HOME/.oh-my-zsh/custom}/plugins/zsh-completions

# 配置zsh主题
RUN sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="xiong-chiamiov-plus"/' ${HOME}/.zshrc

# 创建自定义主题目录（如果不存在）
RUN mkdir -p $HOME/.oh-my-zsh/custom/themes/

# 拷贝主题文件到指定位置
RUN cp ${HOME}/.oh-my-zsh/themes/xiong-chiamiov-plus.zsh-theme $HOME/.oh-my-zsh/custom/themes/

# 使用sed命令在PROMPT=$'后边增加一个换行
RUN sed -i 's/PROMPT=\$'/PROMPT=\$'\n/' $HOME/.oh-my-zsh/custom/themes/xiong-chiamiov-plus.zsh-theme

# 配置zsh插件
RUN sed -i 's/^plugins=(.*)/plugins=(git z sudo extract zsh-autosuggestions zsh-syntax-highlighting zsh-completions)/' ${HOME}/.zshrc

# 配置alias
RUN echo 'alias cls="clear"\nalias cp="cp -rf"\nalias rf="rm -rf"\nalias grepc="find . -iname \"*.c\" | xargs grep -rn --color=auto "\nalias greph="find . -iname \"*.h\" | xargs grep -rn --color=auto "' >> ${HOME}/.zshrc

# 默认启动命令可以是zsh
CMD ["zsh"]

# SSH配置
# RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
#     echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
#     systemctl enable ssh

# Samba配置
# RUN (echo -e "[wanguo]\ncomment = samba share path\nbrowseable = yes\npath = /home/wanguo\ncreate mask = 0700\ndirectory mask = 0700\nvalid users = wanguo\nforce user = wanguo\nforce group = wanguo\npublic = yes\navailable = yes\nwritable = yes" >> /etc/samba/smb.conf) && \
#     echo -e "wanguo\nwanguo" | smbpasswd -s -a wanguo && \
#     systemctl enable smbd

# NFS服务器配置
# RUN mkdir -p /home/wanguo/nfs && chmod 777 /home/wanguo/nfs && \
#     echo "/home/wanguo/nfs *(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports && \
#     systemctl enable nfs-kernel-server

# TFTP服务器配置
# RUN mkdir -p /home/wanguo/tftp && chmod 777 /home/wanguo/tftp && \
#     echo 'TFTP_USERNAME="tftp"\nTFTP_DIRECTORY="/home/wanguo/tftp"\nTFTP_ADDRESS=":69"\nTFTP_OPTIONS="--secure -l -c"' > /etc/default/tftpd-hpa && \
#     systemctl enable tftpd-hpa

