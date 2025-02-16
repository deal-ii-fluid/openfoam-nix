# OpenFOAM Nix 开发环境配置

本项目提供了一个使用 Nix Flakes 配置 OpenFOAM 及其相关工具的完整开发环境。通过 Nix，您可以轻松搭建可重现、隔离且一致的开发环境，避免环境配置带来的问题，专注于 OpenFOAM 开发。

## 包含组件

- **OpenFOAM**：版本 9、10 和 11，提供不同版本的 CFD 模拟环境。
- **solids4foam**：用于固体力学分析的 OpenFOAM 扩展，支持与 OpenFOAM 各版本集成。
- **preCICE**：用于多物理场耦合仿真的开源库，实现 OpenFOAM 与其他物理场求解器的协同工作。
- **preCICE-OpenFOAM Adapter**：连接 OpenFOAM 和 preCICE 的适配器，支持多物理场耦合模拟。
- **preCICE-CalculiX Adapter**：连接 CalculiX 和 preCICE 的适配器，用于结构力学和流体动力学耦合模拟。
- **OpenFOAM 开发工具箱**：包含常用的 OpenFOAM 开发和调试工具，提升开发效率。

## 快速开始

### 开发环境

使用 `nix develop` 命令快速进入各种预配置的开发环境：

```bash
# OpenFOAM 11 开发环境
nix develop .#openfoam-11

# solids4foam 11 开发环境
nix develop .#solids4foam-11

# preCICE-OpenFOAM 11 适配器开发环境
nix develop .#precice-openfoam-11

# preCICE-CalculiX 适配器开发环境
nix develop .#calculix-adapter

# OpenFOAM 工具箱环境 (仅包含开发工具)
nix develop .#openfoam-toolbox

# 默认开发环境 (OpenFOAM 11 + 工具箱)
nix develop
```

### 构建软件包

使用 `nix build` 命令构建独立的软件包：

```bash
# 构建 OpenFOAM 11 软件包
nix build .#openfoam-11

# 构建 solids4foam 11 软件包
nix build .#solids4foam-11

# 构建 preCICE-OpenFOAM 11 适配器软件包
nix build .#precice-openfoam-11

# 构建 preCICE-CalculiX 适配器软件包
nix build .#preciceCalculixAdapter

# 构建 OpenFOAM 工具箱软件包
nix build .#openfoamToolbox
```

### 验证环境

进入开发环境后，您可以验证相关组件是否配置正确：

```bash
# 验证 OpenFOAM 环境
which simpleFoam        # 检查 OpenFOAM 命令是否在 PATH 中
echo $WM_PROJECT_DIR    # 检查 OpenFOAM 项目目录环境变量
simpleFoam -help       # 运行 OpenFOAM 求解器并查看帮助信息

# 验证 solids4foam 环境
echo $SOLIDS4FOAM_DIR   # 检查 solids4foam 安装目录环境变量
solids4Foam -help      # 运行 solids4foam 求解器并查看帮助信息

# 验证 preCICE 环境
precice-tools --version # 检查 preCICE 工具版本
```

## 项目结构详解

```
.
├── flake.nix                    # Nix Flake 主配置文件：定义开发环境和软件包
├── calculix-adapter.nix         # preCICE-CalculiX 适配器构建配置
├── openfoam.nix                 # OpenFOAM 软件包构建配置 (版本 9, 10, 11)
├── openfoam-adapter.nix         # preCICE-OpenFOAM 适配器构建配置
├── openfoam-solids4foam.nix     # solids4foam 扩展软件包构建配置
├── toolbox.nix                  # OpenFOAM 开发工具箱软件包配置
├── solids4foam_versions.json    # solids4foam 版本信息配置文件
└── adapter_versions.json        # 适配器版本信息配置文件
```

## 配置文件详细说明

- **`flake.nix`**
    - **输入源 (inputs)**：
        - `nixpkgs-unstable`：用于获取最新的软件包，主要用于 OpenFOAM 及其工具链。
        - `nixpkgs-2305`：用于 preCICE 及其相关组件，确保版本兼容性。
        - `nixpkgs-specific (70bdadeb94)`：特定版本的 nixpkgs，用于 preCICE-CalculiX 适配器的编译器 (`gcc`/`gfortran`)，解决特定编译问题。
    - **输出 (outputs)**：
        - 定义了各种软件包 (`packages`) 和开发环境 (`devShells`)，例如 OpenFOAM 各版本、solids4foam、preCICE 适配器和工具箱。
        - 使用 `callPackage` 函数调用各个 `.nix` 文件来构建软件包。
        - 开发环境通过 `mkShell` 函数创建，并配置必要的 `buildInputs` 和 `shellHook`。

- **`openfoam.nix`**
    - 定义了构建 OpenFOAM 软件包的 Nix 表达式。
    - 支持构建 OpenFOAM 版本 9、10 和 11。
    - 使用 `ccacheStdenv` 优化编译速度，利用 `ccache` 缓存编译结果。
    - 自动配置 OpenFOAM 的 MPI 环境，支持并行计算。

- **`openfoam-solids4foam.nix`**
    - 定义了构建 solids4foam 软件包的 Nix 表达式。
    - 基于指定的 OpenFOAM 版本构建 solids4foam 扩展。
    - solids4foam 的版本信息在 `solids4foam_versions.json` 中配置，方便版本管理。
    - 支持为多个 OpenFOAM 版本构建 solids4foam。

- **`openfoam-adapter.nix`**
    - 定义了构建 preCICE-OpenFOAM 适配器软件包的 Nix 表达式。
    - 使用 `nixpkgs-2305` 中的 `preCICE` 软件包，确保与适配器版本兼容。
    - 支持为不同 OpenFOAM 版本构建适配器。

- **`calculix-adapter.nix`**
    - 定义了构建 preCICE-CalculiX 适配器软件包的 Nix 表达式。
    - **特别注意**：为了解决编译兼容性问题，此适配器使用了特定版本的 `gcc` 和 `gfortran`，这些编译器来自 `flake.nix` 中 `nixpkgs-specific` 输入源。
    - 所有依赖项（包括编译器、库等）都来自同一 nixpkgs 版本，以确保构建环境的一致性。

- **`toolbox.nix`**
    - 定义了 OpenFOAM 开发工具箱软件包，包含常用的开发和调试工具，例如 `paraview`、`gnumake`、`cmake`、`gcc`、`gdb` 等。
    - 旨在为 OpenFOAM 开发提供便利的工具集。

- **`*.json` 版本信息文件**
    - `solids4foam_versions.json`：存储 solids4foam 各个版本的 Git 仓库信息（URL、commit hash 等），用于版本管理和可追溯性。
    - `adapter_versions.json`：类似地，存储 preCICE 适配器（如果需要版本管理）的版本信息。

## 开发环境核心特性

- **OpenFOAM 环境**
    - 自动配置 OpenFOAM 运行所需的所有环境变量 (`WM_PROJECT_DIR`、`FOAM_APPBIN`、`FOAM_LIBBIN` 等)。
    - 内置可视化工具 `paraview`，方便后处理和结果分析。
    - 兼容 Bash 和 Fish shell，自动加载对应的环境变量脚本 (`set-openfoam-vars` 或 `set-openfoam-vars.fish`)。

- **solids4foam 环境**
    - 完全继承 OpenFOAM 环境的所有特性。
    - 额外设置 `SOLIDS4FOAM_DIR` 环境变量，指向 solids4foam 的安装目录。
    - 预装 solids4foam 开发所需的编译工具链。

- **preCICE 适配器环境**
    - 自动配置 preCICE 运行环境，包括 `precice` 库和工具。
    - 针对 preCICE-OpenFOAM 适配器，额外配置 `FOAM_ADAPTER_DIR` 环境变量，指向适配器安装目录。
    - 提供开发和调试 preCICE 耦合模拟所需的完整依赖库。

## 特别说明

- **编译器版本锁定**：preCICE-CalculiX 适配器强制使用特定版本的 `gcc`/`gfortran`，以规避潜在的编译错误或兼容性问题。
- **nixpkgs 版本混合**：本项目巧妙地混合使用了不同版本的 `nixpkgs` (`unstable` 和 `23.05` 以及特定 commit)，以满足不同组件对软件包版本的要求。
- **Shell 兼容性**：全面支持 Bash 和 Fish shell，自动适配环境变量配置脚本，无需手动干预。
- **首次使用耐心**：首次运行 `nix develop` 或 `nix build` 时，Nix 需要下载和构建所有依赖，耗时较长，请耐心等待。

## 版本管理与自定义

- **OpenFOAM 版本**：在 `versions.json` 文件中集中管理 OpenFOAM 版本信息，方便切换和添加新版本。
- **solids4foam 版本**：在 `solids4foam_versions.json` 文件中管理 solids4foam 版本信息。
- **适配器版本**：如果需要，可以在 `adapter_versions.json` 中管理适配器版本信息。
- **自定义配置**：您可以根据需要修改 `.nix` 文件，例如添加自定义补丁、修改编译选项、添加额外的依赖包等。

## 支持的系统平台

- `x86_64-linux`
- `aarch64-linux`

## 常见问题与解答 (FAQ)

1. **编译错误**：
    - 确保您的 Nix 环境配置正确，Flakes 功能已启用。
    - 检查错误日志，确认是否是由于缺少依赖或编译器版本不兼容导致。
    - 对于 preCICE-CalculiX 适配器，请务必使用 `nix develop .#calculix-adapter` 进入开发环境，以确保使用正确的编译器版本。

2. **环境变量问题**：
    - 如果环境变量设置不正确，尝试退出开发环境 (`exit`) 后重新进入 (`nix develop`)。
    - 检查 `.shellhook` 文件，确认环境变量设置脚本是否正确加载。
    - 对于 Fish shell 用户，请确保安装了 Fish shell 对应的 Nix 集成。

3. **版本兼容性问题**：
    - 本项目已尽力处理各组件之间的版本兼容性问题。
    - 如果您遇到版本冲突，请检查 `flake.nix` 文件中 `nixpkgs` 输入源的配置，并参考各组件的官方文档，确认版本兼容性要求。
    - 如需修改版本，请谨慎操作，并充分测试。

## 许可证

本项目代码采用 [GPLv3](https://www.gnu.org/licenses/gpl-3.0.html) 许可证。

## 贡献

欢迎您为本项目贡献代码和文档！如果您有任何改进建议、功能添加或 Bug 修复，请提交 Issues 或 Pull Requests。您的贡献将使本项目更加完善！
