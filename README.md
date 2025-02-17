# OpenFOAM Nix Flake

这个 Nix Flake 提供了 OpenFOAM 及其相关工具的打包和开发环境。

## 可用包

- OpenFOAM (版本 9, 10, 11)
- preCICE-OpenFOAM 适配器
- solids4foam
- blastfoam (仅支持 OpenFOAM-9)
- CalculiX-preCICE 适配器
- OpenFOAM 开发工具箱

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

## 许可证

GPL-3.0