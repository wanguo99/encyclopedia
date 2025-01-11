# 02-Git-Config-Guide

## 1. 基础配置
# 配置用户名
```bash
git config --global user.name wanguo
```
# 配置邮箱
```bash
git config --global user.email "guohaoprc@163.com"
```

# 屏蔽oh-my-zsh git文件状态扫描，规避进入git目录变卡问题
```bash
git config --global oh-my-zsh.hide-dirty 1
```
```bash
git config --global oh-my-zsh.hide-status 1
```

## 2. SSH key 配置
### 2.1 配置 SSH
git使用SSH配置， 初始需要以下三个步骤
1. 使用秘钥生成工具生成rsa秘钥和公钥
2. 将rsa公钥添加到代码托管平台
3. 将rsa秘钥添加到ssh-agent中，为ssh client指定使用的秘钥文件

#### 2.2.1 检查本地主机是否已经存在 ssh key
看是否存在 id_rsa 和 id_rsa.pub文件，如果存在，说明已经有SSH Key，如果存在，直接跳到第三步
```bash
ls ${HOME}/.ssh
```
#### 2.2.2 生成 ssh key
```bash
ssh-keygen -t rsa -C "guohaoprc@163.com"
```
1. 执行上述命令后一直回车即可
2. 生成完以后再用第二步命令，查看ssh key是否正常生成
3. 获取ssh key公钥内容（id_rsa.pub）
```bash
cat ~/.ssh/id_rsa.pub
```
#### 2.2.3 Github账号上添加公钥
1. 进入Settings设置
2. 添加ssh key，把刚才复制的内容粘贴上去保存即可
#### 2.2.4 验证ssh key是否设置成功
```bash
ssh -T git@github.com
```
显示如下信息，证明ssh key设置成功
```bash
Hi isGuoHao! You've successfully authenticated, but GitHub does not provide shell access.
```

## 3. git commit format
```
git commit . --amend -m "- Issues:
- Date: `date "+%Y/%m/%d %H:%M:%S"`
- Author: `whoami`"
```



