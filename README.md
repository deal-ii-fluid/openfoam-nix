# OpenFOAM Nix 开发环境配置

本项目旨在提供一个使用 Nix Flakes 和 Nix 包管理器配置 OpenFOAM 开发环境的示例。通过 Nix，您可以轻松地搭建可重现、隔离且一致的 OpenFOAM 开发环境，避免环境配置带来的问题。

## 项目文件说明

- **`flake.nix`**:  Nix Flakes 配置文件，用于定义可重现的开发环境和软件包。您需要使用此文件以及 `nix develop` 或 `nix build` 命令来管理开发环境。
- **`overlays.nix`**:  Nix Overlays 配置文件，用于覆盖 nixpkgs 中的软件包定义。本项目中，它用于引入 `ccacheWrapper` 和 `openfoam11` 的自定义配置。
- **`openfoam.nix`**:  OpenFOAM 软件包的 Nix 定义文件，描述了如何构建 OpenFOAM 11 版本。
- **`fix-config.patch`**:  用于修复 OpenFOAM 配置文件的补丁，可能包含一些小的调整以使其更好地与 Nix 环境工作。
- **`ryax_metadata.yaml`**, **`ryax_handler.py`**, **`script.sh`**, **`logo.png`**, **`README.md`**:  这些文件是项目中的其他辅助文件，与 Nix 环境配置本身关系不大，您可以根据您的项目需求进行修改或删除。

## 如何使用 (`nix develop` - 推荐)

如果您希望使用 Nix Flakes 来管理您的开发环境，请按照以下步骤操作：

1. **确保已启用 Nix Flakes 功能**:  如果尚未启用，请按照 Nix 官方文档指引启用 Flakes 功能。
2. **进入开发环境**:  在项目根目录下运行命令：
   ```bash
   nix develop
   ```
   首次运行会下载 Nixpkgs 和构建 OpenFOAM 环境，可能需要一些时间。
3. **验证环境**:  进入开发环境后，您可以验证 OpenFOAM 是否已正确配置：
   ```bash
   which simpleFoam
   echo $WM_PROJECT_DIR
   simpleFoam -help
   ```
   如果 `which simpleFoam` 命令能够找到 `simpleFoam` 可执行文件，并且 `simpleFoam -help` 可以正常运行，则说明 OpenFOAM 环境已配置成功。

## 注意事项

- 首次构建 OpenFOAM 环境可能需要较长时间，请耐心等待。
- 如果您在使用过程中遇到任何问题，请检查错误信息并参考 Nix 和 OpenFOAM 的文档。

希望这个 Nix 配置能够帮助您更高效地进行 OpenFOAM 开发！

## Shell 支持

本项目支持 bash 和 fish shell：

- Bash 用户会自动使用 `set-openfoam-vars`
- Fish 用户会自动使用 `set-openfoam-vars.fish`

环境变量会根据您使用的 shell 自动正确设置。
