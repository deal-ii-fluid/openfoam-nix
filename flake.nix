{
  description = "OpenFOAM Project Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # 或根据需要选择合适的版本
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      overlay = import ./overlays.nix;
    in {
      packages = forAllSystems (system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in {
        openfoam11 = pkgs.openfoam11;
      });

      devShells = forAllSystems (system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [ 
            openfoam11
            paraview
            findutils
            coreutils
            gnused
            openmpi
            openssh
            binutils
            gnugrep
          ];

          shellHook = ''
            # 设置 OpenFOAM 环境变量
            export WM_PROJECT=OpenFOAM
            export WM_PROJECT_VERSION=11
            export WM_COMPILER=Gcc
            export WM_COMPILER_TYPE=system
            export WM_PRECISION_OPTION=DP
            export WM_LABEL_SIZE=32
            export WM_COMPILE_OPTION=Opt
            export WM_MPLIB=SYSTEMOPENMPI

            # 设置系统特定的选项
            export WM_ARCH=linuxArm64  # 对于 aarch64 系统
            export WM_ARCH_OPTION=64
            export WM_OPTIONS=$WM_ARCH$WM_COMPILER$WM_PRECISION_OPTION$WM_LABEL_SIZE$WM_COMPILE_OPTION

            # 设置路径
            export WM_PROJECT_DIR=${pkgs.openfoam11}/OpenFOAM-$WM_PROJECT_VERSION
            export WM_PROJECT_USER_DIR=$HOME/OpenFOAM/$USER-$WM_PROJECT_VERSION
            export WM_THIRD_PARTY_DIR=${pkgs.openfoam11}/ThirdParty-$WM_PROJECT_VERSION

            # 添加到 PATH
            export PATH=$WM_PROJECT_DIR/platforms/$WM_OPTIONS/bin:$PATH
            export PATH=$WM_PROJECT_DIR/bin:$PATH
            export PATH=$WM_PROJECT_DIR/wmake:$PATH

            # 设置库路径
            export LD_LIBRARY_PATH=$WM_PROJECT_DIR/platforms/$WM_OPTIONS/lib:$LD_LIBRARY_PATH
            export LD_LIBRARY_PATH=$WM_THIRD_PARTY_DIR/platforms/$WM_OPTIONS/lib:$LD_LIBRARY_PATH

            # 创建用户目录
            mkdir -p $WM_PROJECT_USER_DIR

            # 输出一些信息以确认设置
            echo "OpenFOAM $WM_PROJECT_VERSION environment set up:"
            echo "  WM_PROJECT_DIR    = $WM_PROJECT_DIR"
            echo "  WM_PROJECT_USER_DIR = $WM_PROJECT_USER_DIR"
            echo "  WM_OPTIONS        = $WM_OPTIONS"
          '';
        };
      });
    };
} 