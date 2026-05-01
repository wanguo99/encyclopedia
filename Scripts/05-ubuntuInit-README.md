# Ubuntu 开发环境自动部署脚本使用说明

## 功能特性

- ✅ **完全幂等性**：可重复执行，已完成的步骤自动跳过
- ✅ **断点续传**：失败后再次执行从中断处继续
- ✅ **状态追踪**：记录每个步骤的完成状态
- ✅ **错误隔离**：单个步骤失败不影响其他步骤
- ✅ **双模式支持**：交互模式 + 全自动模式

## 使用方法

### 1. 交互模式（推荐首次使用）

```bash
sudo ./05-ubuntuInit.sh
```

脚本会逐步询问是否执行每个配置项。

### 2. 全自动模式

```bash
sudo AUTO_MODE=1 ./05-ubuntuInit.sh
```

使用默认配置，跳过所有交互提示。

### 3. 自定义自动模式

通过环境变量控制具体行为：

```bash
sudo AUTO_MODE=1 \
     INSTALL_SAMBA=1 \
     SAMBA_PASSWORD="your_password" \
     INSTALL_NFS=1 \
     CONFIG_GIT=1 \
     GIT_USERNAME="your_name" \
     GIT_EMAIL="your@email.com" \
     CONFIG_PROXY=1 \
     PROXY_ADDRESS="http://192.168.1.1:7890" \
     ./05-ubuntuInit.sh
```

## 环境变量说明

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `AUTO_MODE` | 启用全自动模式 | 0 (交互模式) |
| `SKIP_APT_SOURCE` | 跳过APT源配置 | 0 (不跳过) |
| `ENABLE_ROOT_SSH` | 允许root SSH登录 | 0 (不允许) |
| `INSTALL_SAMBA` | 安装Samba | 0 (不安装) |
| `SAMBA_PASSWORD` | Samba密码 | 无 (需交互输入) |
| `INSTALL_NFS` | 安装NFS | 0 (不安装) |
| `INSTALL_TFTP` | 安装TFTP | 0 (不安装) |
| `CONFIG_GIT` | 配置Git | 0 (不配置) |
| `GIT_USERNAME` | Git用户名 | 无 (需交互输入) |
| `GIT_EMAIL` | Git邮箱 | 无 (需交互输入) |
| `GIT_PROXY` | Git代理地址 | 无 |
| `CONFIG_PROXY` | 配置系统代理 | 0 (不配置) |
| `PROXY_ADDRESS` | 系统代理地址 | 无 (格式: http://IP:PORT) |

## 状态管理

### 查看已完成的步骤

```bash
cat ~/.ubuntu-init-state/completed_steps
```

### 重新执行某个步骤

删除状态文件中对应的行，然后重新运行脚本：

```bash
# 例如重新执行Git配置
sed -i '/^git$/d' ~/.ubuntu-init-state/completed_steps
sudo ./05-ubuntuInit.sh
```

### 完全重置（重新执行所有步骤）

```bash
rm -rf ~/.ubuntu-init-state
sudo ./05-ubuntuInit.sh
```

## 配置步骤列表

脚本会依次执行以下步骤：

1. **apt_source** - 配置APT镜像源（使用apt-select自动选择最快源）
2. **system_update** - 更新系统软件包
3. **basic_packages** - 安装基础开发工具
4. **timezone** - 配置时区为Asia/Shanghai
5. **ssh** - 配置SSH服务
6. **samba** - 配置Samba文件共享（可选）
7. **git** - 配置Git用户信息（可选）
8. **system_proxy** - 配置系统代理（可选，用于加速后续网络操作）
9. **zsh** - 安装配置Zsh和Oh-My-Zsh
10. **nfs** - 配置NFS服务器（可选）
11. **tftp** - 配置TFTP服务器（可选）

## 常见问题

### Q: 脚本执行到一半失败了怎么办？

A: 直接重新运行脚本，已完成的步骤会自动跳过，从失败的地方继续。

### Q: 如何跳过某些不需要的配置？

A: 交互模式下选择"n"跳过，或在自动模式下不设置对应的环境变量。

### Q: Oh-My-Zsh插件安装失败怎么办？

A: 脚本会自动跳过失败的插件继续执行。可以稍后手动安装：

```bash
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
  ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
```

### Q: 如何验证某个服务是否配置成功？

A: 使用systemctl检查服务状态：

```bash
systemctl status sshd      # SSH
systemctl status smbd      # Samba
systemctl status nfs-kernel-server  # NFS
systemctl status tftpd-hpa # TFTP
```

## 完整示例

### 示例1：最小化安装（仅基础环境）

```bash
sudo AUTO_MODE=1 SKIP_APT_SOURCE=1 ./05-ubuntuInit.sh
```

### 示例2：开发环境（含Git配置）

```bash
sudo AUTO_MODE=1 \
     CONFIG_GIT=1 \
     GIT_USERNAME="Zhang San" \
     GIT_EMAIL="zhangsan@example.com" \
     ./05-ubuntuInit.sh
```

### 示例3：完整服务器环境（含代理）

```bash
sudo AUTO_MODE=1 \
     CONFIG_PROXY=1 \
     PROXY_ADDRESS="http://192.168.1.1:7890" \
     INSTALL_SAMBA=1 \
     SAMBA_PASSWORD="samba123" \
     INSTALL_NFS=1 \
     INSTALL_TFTP=1 \
     CONFIG_GIT=1 \
     GIT_USERNAME="Admin" \
     GIT_EMAIL="admin@example.com" \
     ./05-ubuntuInit.sh
```

## 系统代理配置说明

### 为什么需要配置系统代理？

在网络受限环境下，配置系统代理可以：
- 加速Oh-My-Zsh及其插件的下载（从GitHub）
- 确保Git操作正常进行
- 加速APT软件包下载
- 避免因网络问题导致安装失败

### 代理配置范围

系统代理会自动配置以下组件：
1. **环境变量** - `/etc/environment` 和用户shell配置文件
2. **APT** - `/etc/apt/apt.conf.d/95proxies`
3. **当前会话** - 立即生效，无需重启
4. **用户环境** - `.bashrc` 和 `.zshrc`

### 代理地址格式

支持以下格式：
- `http://192.168.1.1:7890`
- `192.168.1.1:7890` （自动添加http://前缀）
- `http://proxy.example.com:8080`

### 取消代理配置

如需取消代理，手动编辑以下文件并删除代理相关行：
```bash
sudo nano /etc/environment
sudo rm /etc/apt/apt.conf.d/95proxies
nano ~/.bashrc
nano ~/.zshrc
```

## 注意事项

1. 必须使用 `sudo` 运行脚本
2. 首次运行建议使用交互模式，了解每个步骤的作用
3. APT源配置会测试多个镜像源，可能需要几分钟
4. Zsh配置完成后需要重新登录才能生效
5. 所有配置文件都会自动备份为 `.bak` 文件
6. 状态文件保存在 `~/.ubuntu-init-state/` 目录

## 故障排查

### 查看详细日志

脚本输出包含时间戳和详细的执行信息，建议保存日志：

```bash
sudo ./05-ubuntuInit.sh 2>&1 | tee ubuntu-init.log
```

### 手动清理失败的安装

如果某个步骤反复失败，可以手动清理后重试：

```bash
# 清理oh-my-zsh
rm -rf ~/.oh-my-zsh

# 清理状态
sed -i '/^zsh$/d' ~/.ubuntu-init-state/completed_steps

# 重新运行
sudo ./05-ubuntuInit.sh
```
