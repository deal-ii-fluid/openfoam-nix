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
      versions = builtins.fromJSON (builtins.readFile ./versions.json); # 读取 versions.json
    in {
      packages = forAllSystems (system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
        makeOpenFOAM = versionName: versionInfo:
          pkgs.callPackage ./openfoam.nix {
            stdenv = pkgs.ccacheStdenv;
            versionInfo = versionInfo;
          };
      in
        nixpkgs.lib.mapAttrs makeOpenFOAM versions
      );

      defaultPackage = forAllSystems (system:
        self.packages.${system}.openfoam-11
      );

      devShells = forAllSystems (system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
        makeDevShell = versionName: versionInfo: let
          version = builtins.substring 9 2 versionName;
        in pkgs.mkShell {
          buildInputs = with pkgs; [
            (self.packages.${system}.${versionName})
            paraview
            findutils
            coreutils
            gnused
            openmpi
            openssh
            binutils
            gnugrep
            zlib
            flex
            scotch
            gnumake
            m4
          ];

          shellHook = ''
            # 基础 OpenFOAM 环境变量
            export FOAM_API=${version}
            export WM_PROJECT=OpenFOAM
            export WM_PROJECT_VERSION=${version}
            export FOAM_MPI=sys-openmpi
            export WM_MPLIB=SYSTEMOPENMPI

            # 编译器和构建选项
            export WM_COMPILER=Gcc
            export WM_COMPILER_TYPE=system
            export WM_COMPILE_OPTION=Opt
            export WM_LABEL_OPTION=Int32
            export WM_LABEL_SIZE=32
            export WM_PRECISION_OPTION=DP

            # 架构和选项设置
            export WM_ARCH=linuxArm64  # 专门为 ARM64 架构设置
            export WM_OPTIONS=$WM_ARCH$WM_COMPILER$WM_PRECISION_OPTION$WM_LABEL_OPTION$WM_COMPILE_OPTION

            # 主要目录路径
            export WM_PROJECT_DIR=${self.packages.${system}.${versionName}}/${versionInfo.OpenFOAM.name}
            export WM_PROJECT_USER_DIR=$HOME/OpenFOAM/$USER-$WM_PROJECT_VERSION
            export WM_THIRD_PARTY_DIR=${self.packages.${system}.${versionName}}/${versionInfo.ThirdParty.name}

            # OpenFOAM 源代码和应用程序路径
            export FOAM_APP=$WM_PROJECT_DIR/applications
            export FOAM_SRC=$WM_PROJECT_DIR/src
            export FOAM_SOLVERS=$FOAM_APP/solvers
            export FOAM_UTILITIES=$FOAM_APP/utilities
            export FOAM_ETC=$WM_PROJECT_DIR/etc
            export FOAM_TUTORIALS=$WM_PROJECT_DIR/tutorials

            # 二进制和库文件路径
            export FOAM_APPBIN=$WM_PROJECT_DIR/platforms/$WM_OPTIONS/bin
            export FOAM_LIBBIN=$WM_PROJECT_DIR/platforms/$WM_OPTIONS/lib
            export FOAM_USER_LIBBIN=$WM_PROJECT_USER_DIR/platforms/$WM_OPTIONS/lib
            export FOAM_USER_APPBIN=$WM_PROJECT_USER_DIR/platforms/$WM_OPTIONS/bin

            # wmake 设置
            export WM_DIR=$WM_PROJECT_DIR/wmake
            export WM_NCOMPPROCS=$(nproc)

            # PATH 设置
            export PATH=$WM_DIR:$PATH
            export PATH=$WM_PROJECT_DIR/bin:$PATH
            export PATH=$FOAM_APPBIN:$PATH

            # LD_LIBRARY_PATH 设置
            export LD_LIBRARY_PATH=$WM_PROJECT_DIR/platforms/$WM_OPTIONS/lib:$LD_LIBRARY_PATH
            export LD_LIBRARY_PATH=$WM_THIRD_PARTY_DIR/platforms/$WM_OPTIONS/lib:$LD_LIBRARY_PATH
            export LD_LIBRARY_PATH=$FOAM_USER_LIBBIN:$LD_LIBRARY_PATH
            export LD_LIBRARY_PATH=$FOAM_LIBBIN:$LD_LIBRARY_PATH
            export LD_LIBRARY_PATH=$FOAM_LIBBIN/dummy:$LD_LIBRARY_PATH

            # 创建用户目录
            mkdir -p $WM_PROJECT_USER_DIR
            mkdir -p $FOAM_USER_APPBIN
            mkdir -p $FOAM_USER_LIBBIN

            # 输出环境信息
            echo "OpenFOAM $WM_PROJECT_VERSION 环境已设置:"
            echo "  WM_PROJECT_DIR     = $WM_PROJECT_DIR"
            echo "  WM_PROJECT_USER_DIR = $WM_PROJECT_USER_DIR"
            echo "  WM_OPTIONS         = $WM_OPTIONS"
            echo "  FOAM_APPBIN        = $FOAM_APPBIN"
            echo "  FOAM_LIBBIN        = $FOAM_LIBBIN"
          '';
        };
      in
        nixpkgs.lib.mapAttrs makeDevShell versions // {
          default = nixpkgs.lib.mapAttrs makeDevShell versions.openfoam-11;
        }
      );

      defaultDevShell = forAllSystems (system: self.devShells.${system}.default);
    };
} 