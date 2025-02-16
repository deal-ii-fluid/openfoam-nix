{
  description = "OpenFOAM Project Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # 或根据需要选择合适的版本
    nixpkgs-2305.url = "github:NixOS/nixpkgs/nixos-23.05";  # 添加 23.05 版本
  };

  outputs = { self, nixpkgs, nixpkgs-2305 }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      overlay = import ./overlays.nix;
      versions = builtins.fromJSON (builtins.readFile ./versions.json); # 读取 versions.json

      # 添加 nixpkgs-2305
      pkgs-2305 = forAllSystems (system: import nixpkgs-2305 {
        inherit system;
        config.allowUnfree = true;
      });

      # 辅助函数：创建 precice-openfoam-adapter 包
      makePreciceAdapter = system: openfoamPkg: 
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
            config.allowUnfree = true;
          };
        in pkgs.callPackage ./openfoam-adapter.nix {
          openfoam = openfoamPkg;
          precice = pkgs-2305.${system}.precice;
        };
    in {
      packages = forAllSystems (system: 
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
            config.allowUnfree = true;
          };
          
          # 创建 OpenFOAM 包
          makeOpenFOAM = versionName: versionInfo:
            pkgs.callPackage ./openfoam.nix {
              stdenv = pkgs.ccacheStdenv;
              versionInfo = versionInfo;
            };
          
          # 创建基础 OpenFOAM 包
          openfoamPkgs = nixpkgs.lib.mapAttrs makeOpenFOAM versions;
          
          # 创建 precice-openfoam-adapter 包
          preciceAdapterPkgs = builtins.listToAttrs (map (version: {
            name = "precice-openfoam-${version}";
            value = makePreciceAdapter system openfoamPkgs."openfoam-${version}";
          }) ["9" "10" "11"]);
        in
          openfoamPkgs // preciceAdapterPkgs
      );

      defaultPackage = forAllSystems (system:
        self.packages.${system}.openfoam-11
      );

      devShells = forAllSystems (system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
          config.allowUnfree = true;
        };
        
        # 基础 OpenFOAM 开发环境
        makeDevShell = versionName: versionInfo: let
          version = builtins.substring 9 2 versionName;
          openfoamPackage = self.packages.${system}.${versionName};
        in pkgs.mkShell {
          buildInputs = with pkgs; [
            openfoamPackage
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
            # 检测当前 shell 类型并相应地 source 环境变量
            if test -n "$FISH_VERSION"
            then
              # Fish shell
              source ${openfoamPackage}/bin/set-openfoam-vars.fish
            else
              # Bash 或其他 shell
              source ${openfoamPackage}/bin/set-openfoam-vars
            fi

            # 输出环境信息
            echo "OpenFOAM $WM_PROJECT_VERSION 环境已设置:"
            echo "  WM_PROJECT_DIR     = $WM_PROJECT_DIR"
            echo "  WM_PROJECT_USER_DIR = $WM_PROJECT_USER_DIR"
            echo "  WM_OPTIONS         = $WM_OPTIONS"
            echo "  FOAM_APPBIN        = $FOAM_APPBIN"
            echo "  FOAM_LIBBIN        = $FOAM_LIBBIN"
          '';
        };

        # preCICE adapter 开发环境
        makePreciceDevShell = versionName: versionInfo: let
          version = builtins.substring 9 2 versionName;
          openfoamPackage = self.packages.${system}.${versionName};
          adapterPackage = pkgs.callPackage ./openfoam-adapter.nix {
            openfoam = openfoamPackage;
            precice = pkgs-2305.${system}.precice;  # 使用 23.05 的 precice
          };
          inherit (pkgs) lib;
        in pkgs.mkShell {
          buildInputs = with pkgs; [
            openfoamPackage
            adapterPackage
            precice
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
            # 检测当前 shell 类型并相应地 source 环境变量
            if test -n "$FISH_VERSION"
            then
              # Fish shell
              source ${openfoamPackage}/bin/set-openfoam-vars.fish
            else
              # Bash 或其他 shell
              source ${openfoamPackage}/bin/set-openfoam-vars
            fi
            
            # 如果是 precice 环境，设置 adapter 环境
            ${lib.optionalString (adapterPackage != null) ''
              export FOAM_ADAPTER_DIR=${adapterPackage}
              export LD_LIBRARY_PATH=${adapterPackage}/lib:$LD_LIBRARY_PATH
            ''}
            
            # 输出环境信息
            echo "OpenFOAM $WM_PROJECT_VERSION 环境已设置:"
            echo "  WM_PROJECT_DIR     = $WM_PROJECT_DIR"
            echo "  WM_PROJECT_USER_DIR = $WM_PROJECT_USER_DIR"
            echo "  WM_OPTIONS         = $WM_OPTIONS"
            echo "  FOAM_APPBIN        = $FOAM_APPBIN"
            echo "  FOAM_LIBBIN        = $FOAM_LIBBIN"
            ${lib.optionalString (adapterPackage != null) ''
              echo "  FOAM_ADAPTER_DIR    = $FOAM_ADAPTER_DIR"
            ''}
          '';
        };
      in
        # 生成所有版本的开发环境
        (nixpkgs.lib.mapAttrs makeDevShell versions) // {
          # 为每个 OpenFOAM 版本创建对应的 precice adapter 环境
          "precice-openfoam-9" = makePreciceDevShell "openfoam-9" versions.openfoam-9;
          "precice-openfoam-10" = makePreciceDevShell "openfoam-10" versions.openfoam-10;
          "precice-openfoam-11" = makePreciceDevShell "openfoam-11" versions.openfoam-11;
          
          # 默认环境
          default = makeDevShell "openfoam-11" versions.openfoam-11;
        }
      );

      defaultDevShell = forAllSystems (system: self.devShells.${system}.default);
    };
} 