# 使用官方Ubuntu最新镜像作为基础镜像
FROM ubuntu:latest

# 设置环境变量，避免交互式配置提示
ENV DEBIAN_FRONTEND=noninteractive

# 替换为阿里云的APT源
RUN sed -i 's@archive.ubuntu.com@mirrors.aliyun.com@g' /etc/apt/sources.list && \
    sed -i 's@security.ubuntu.com@mirrors.aliyun.com@g' /etc/apt/sources.list

# 更新软件包列表并安装必要的软件包
RUN apt update -y && apt upgrade -y

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
    llvm

RUN rm -rf /var/lib/apt/lists/*

# 创建新用户wanguo，并设置密码
RUN useradd -m wanguo && echo "wanguo:p" | chpasswd

# 创建挂载点目录
RUN mkdir -p /home/wanguo/HostMount && \
    chown -R wanguo:wanguo /home/wanguo/HostMount

# 切换到新创建的用户
USER wanguo

# 设置工作目录
WORKDIR /home/wanguo

RUN sh -c "$(curl -fsSL https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh)" ""

# 默认启动命令可以是zsh
CMD ["zsh"]
