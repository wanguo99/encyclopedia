# 05-preCICE-Installation-Guide

# 1. 下载spack仓库
```bash
	git clone -b develop https://github.com/spack/spack.git
```

# 2. 开启spack
```bash
	source spack/share/spack/setup-env.sh
```

# 3. 创建一个spack环境，名字自己定 【以 test_env 为例】
```bash
	spack env create test_env
```

# 4. 启用 test_env 环境
```bash
	spack env activate test_env
```

# 5. 安装precice
## 5.1 安装编译工具链
```bash
sudo apt install -y build-essential gfortran pkg-config

# 配置编译器
spack compiler find

```
## 5.2 安装precice
```bash
	spack add precice
	spack install
```

# 6. 安装openfoam
```bash
	spack add openfoam
	spack install
```

# 7. 安装openfoam-adapter
```bash
	wget https://github.com/precice/openfoam-adapter/archive/refs/tags/v1.3.1.tar.gz
	tar -xvf v1.3.1.tar.gz
	cd openfoam-adapter-1.3.1
	./Allwmake
```

# 8. 安装CalculiX-adapter
```bash
	wget https://github.com/precice/calculix-adapter/archive/refs/heads/master.tar.gz
	tar -xzf master.tar.gz
	cd calculix-adapter-master
	make -j $(nproc)
```

# 9. 加载 precice
```bash
	spack load precice
```

# 10. 验证ccx_preCICE是否可用
```bash
	~/calculix-adapter-master/bin/ccx_preCICE -v
```

# 11. 下载 tutorials
```bash
	git clone https://github.com/precice/tutorials.git
	cd tutorials/flow-over-heated-plate
```

# 13. 修改solid-calculix/run.sh
```bash
	# 把原来的注释掉，改成第二行这个
	# ccx_preCICE -i tube -precice-participant Solid
	~/calculix-adapter-master/bin/ccx_preCICE -i tube -precice-participant Solid
```

# 14. 运行 solid-calculix 里边的 run.sh
```bash
	# 【必须】 重新开一个窗口，重新加载spack环境：
	source ~/spack/share/spack/setup-env.sh
	spack env activate test_env
	spack load precice
	
	# 运行 solid-calculix
	cd solid-calculix && ./run.sh
```
	
# 15. 运行fluid-openfoam 里边的 run.sh
```bash
	# 【必须】 重新开一个窗口，重新加载spack环境：
	source ~/spack/share/spack/setup-env.sh
	spack env activate test_env
	spack load precice
	
	# 运行 fluid-openfoam
	cd fluid-openfoam && ./run.sh
```

