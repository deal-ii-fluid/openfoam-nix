# OpenFOAM Nix Flake

[![Test](https://github.com/deal-ii-fluid/openfoam-nix/actions/workflows/test.yml/badge.svg)](https://github.com/deal-ii-fluid/openfoam-nix/actions/workflows/test.yml)

这个 Nix Flake 提供了 OpenFOAM 及其相关工具的打包和开发环境。

## 状态

- ✅ OpenFOAM 9/10/11: 已支持
- ✅ preCICE-OpenFOAM 适配器: 已支持
- ✅ solids4foam: 已支持
- ✅ blastfoam: 已支持 (仅 OpenFOAM-9)
- ✅ CalculiX-preCICE 适配器: 已支持

## 可用包

- OpenFOAM (版本 9, 10, 11)
- preCICE-OpenFOAM 适配器
- solids4foam
- blastfoam (仅支持 OpenFOAM-9)
- CalculiX-preCICE 适配器
- OpenFOAM 开发工具箱

## 要求

- Nix 包管理器 (启用 flakes 功能)
- Git

## 使用二进制缓存

```bash
# 启用 Cachix 缓存
cachix use jiaqiwang969
```

## 多架构支持

本项目支持以下架构：
- x86_64-linux
- aarch64-linux

### 构建和推送到 Cachix

1. **构建单个包**
```bash
# 在当前架构上构建并推送 OpenFOAM-9
./push-to-cachix.sh openfoam-9

# 构建其他包
./push-to-cachix.sh blastfoam-9
./push-to-cachix.sh solids4foam-9
./push-to-cachix.sh precice-openfoam-9
```

2. **构建所有包**
```bash
# 在当前架构上构建并推送所有包
./push-to-cachix.sh
```

3. **查看可用包列表**
```bash
./push-to-cachix.sh help
```

### 跨架构构建

如果您想在一个架构上构建另一个架构的包：

1. **使用 binfmt 和 QEMU**
```bash
# 在 x86_64 上构建 aarch64 包
sudo apt-get install qemu-user-static binfmt-support

# 或在 NixOS 上
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```

2. **使用远程构建器**
```bash
# 配置远程构建器
nix.buildMachines = [{
  hostName = "builder";
  system = "aarch64-linux";
  # ...其他配置
}];
```

### CI/CD

GitHub Actions 工作流程会自动：
1. 在代码更改时构建并推送到 Cachix (`build.yml`)
2. 在 PR 和推送时进行测试 (`test.yml`)
3. 同时支持 x86_64 和 aarch64 架构

## 快速开始

首先设置 Cachix 缓存：
```bash
# 安装 Cachix
nix-env -iA nixpkgs.cachix

# 使用 openfoam-nix 缓存
cachix use jiaqiwang969
```

```bash
# 克隆仓库
git clone https://github.com/deal-ii-fluid/openfoam-nix.git
cd openfoam-nix

# 构建 OpenFOAM
nix build .#openfoam-9

# 进入开发环境
nix develop .#openfoam-9
```

## 使用方法

### 构建包

```bash
# 构建 OpenFOAM
nix build .#openfoam-9
nix build .#openfoam-10
nix build .#openfoam-11

# 构建 preCICE 适配器
nix build .#precice-openfoam-9
nix build .#precice-openfoam-10
nix build .#precice-openfoam-11

# 构建 solids4foam
nix build .#solids4foam-9
nix build .#solids4foam-10
nix build .#solids4foam-11

# 构建 blastfoam
nix build .#blastfoam-9

# 构建 CalculiX 适配器
nix build .#precice-calculix-adapter
```

### 开发环境

```bash
# OpenFOAM 开发环境
nix develop .#openfoam-9
nix develop .#openfoam-10
nix develop .#openfoam-11

# preCICE-OpenFOAM 开发环境
nix develop .#precice-openfoam-9
nix develop .#precice-openfoam-10
nix develop .#precice-openfoam-11

# solids4foam 开发环境
nix develop .#solids4foam-9
nix develop .#solids4foam-10
nix develop .#solids4foam-11

# blastfoam 开发环境
nix develop .#blastfoam-9

# CalculiX 适配器开发环境
nix develop .#calculix-adapter

# 工具箱环境
nix develop .#openfoam-toolbox
```

## 特性

- 支持多个 OpenFOAM 版本
- 提供完整的开发环境
- 包含常用工具和依赖
- 支持 Fish shell
- 自动设置所有必要的环境变量
- 支持 FSI (Fluid-Structure Interaction) 求解器
- 支持压缩流求解器 (blastfoam)
- 持续集成和自动测试
- Cachix 二进制缓存支持

## 开发环境包含

- OpenFOAM
- ParaView
- 编译工具 (gcc, make, cmake)
- 调试工具 (gdb)
- MPI 支持 (OpenMPI)
- 版本控制工具
- 其他必要的系统工具

## 注意事项

- blastfoam 目前仅支持 OpenFOAM-9 版本
- 所有开发环境都会自动设置必要的环境变量
- 支持 bash 和 fish shell
- 用户文件默认存储在 `/tmp/OpenFOAM-${version}` 目录
- 首次构建可能需要较长时间
- 建议使用 Cachix 以加快构建速度

## 贡献

欢迎提交 Pull Requests 和 Issues！

## 许可证

GPL-3.0