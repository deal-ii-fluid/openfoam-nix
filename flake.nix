{
  description = "OpenFOAM Project Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # 或根据需要选择合适的版本
    nixpkgs-2305.url = "github:NixOS/nixpkgs/nixos-23.05";  # 添加 23.05 版本
  };

  outputs = { self, nixpkgs, nixpkgs-2305 }:
    let
      supportedSystems = [ "x86_4-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      overlay = import ./overlays.nix;
      versions = builtins.fromJSON (builtins.readFile ./versions.json); # 读取 versions.json
      solids4foamVersions = builtins.fromJSON (builtins.readFile ./solids4foam_versions.json);

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

      # 辅助函数：创建 solids4foam 包
      makeSolids4Foam = system: openfoamPkg: versionKey:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
            config.allowUnfree = true;
          };
          versionInfo = solids4foamVersions.${versionKey};
        in pkgs.callPackage ./openfoam-solids4foam.nix {
          inherit openfoamPkg versionInfo;
        };

    in {
      packages = forAllSystems (system: 
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
            config.allowUnfree = true;
          };
          
          # 创建工具箱包
          toolbox = pkgs.callPackage ./toolbox.nix {};
          
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

          # 创建 solids4foam 包
          solids4foamPkgs = builtins.listToAttrs (map (version: {
            name = "solids4foam-${version}";
            value = makeSolids4Foam system openfoamPkgs."openfoam-${version}" "v${version}";
          }) ["9" "10" "11"]);
        in
          openfoamPkgs // preciceAdapterPkgs // solids4foamPkgs // {
            inherit toolbox;  # 添加工具箱包
          }
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
        
        toolbox = self.packages.${system}.toolbox;
        
        # 创建带工具箱的 OpenFOAM 开发环境
        makeDevShellWithTools = versionName: versionInfo: let
          openfoamPackage = self.packages.${system}.${versionName};
        in pkgs.mkShell {
          buildInputs = [
            openfoamPackage
            toolbox  # 添加工具箱
          ];

          shellHook = ''
            source ${openfoamPackage}/bin/set-openfoam-vars
            
            echo "OpenFOAM $WM_PROJECT_VERSION 开发环境已设置"
            echo "包含常用开发工具"
          '';
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

        # 创建 solids4foam 开发环境
        makeSolids4FoamDevShell = versionName: let
          version = builtins.substring 9 2 versionName;
          openfoamPackage = self.packages.${system}.${versionName};
          solids4foamPackage = pkgs.callPackage ./openfoam-solids4foam.nix {
            openfoam = openfoamPackage;
            versionInfo = solids4foamVersions."v${version}";
            inherit (pkgs.ocamlPackages) bigarray;
          };
        in pkgs.mkShell {
          buildInputs = with pkgs; [
            openfoamPackage
            solids4foamPackage
            paraview
            gnumake
            cmake
            gcc
            gdb
          ];

          shellHook = ''
            # 检测当前 shell 类型并相应地 source 环境变量
            if test -n "$FISH_VERSION"
            then
              source ${openfoamPackage}/bin/set-openfoam-vars.fish
            else
              source ${openfoamPackage}/bin/set-openfoam-vars
            fi
            
            # 设置 solids4foam 环境变量
            export SOLIDS4FOAM_DIR=${solids4foamPackage}
            export LD_LIBRARY_PATH=${solids4foamPackage}/lib:$LD_LIBRARY_PATH
            
            echo "OpenFOAM-solids4foam 环境已设置:"
            echo "  WM_PROJECT_DIR     = $WM_PROJECT_DIR"
            echo "  SOLIDS4FOAM_DIR    = $SOLIDS4FOAM_DIR"
          '';
        };
      in
        # 生成所有版本的开发环境
        (nixpkgs.lib.mapAttrs makeDevShellWithTools versions) // {
          # 为每个 OpenFOAM 版本创建对应的 precice adapter 环境
          "precice-openfoam-9" = makePreciceDevShell "openfoam-9" versions.openfoam-9;
          "precice-openfoam-10" = makePreciceDevShell "openfoam-10" versions.openfoam-10;
          "precice-openfoam-11" = makePreciceDevShell "openfoam-11" versions.openfoam-11;
          
          # 默认环境
          default = makeDevShellWithTools "openfoam-11" versions.openfoam-11;
          
          # 添加纯工具箱环境
          "openfoam-toolbox" = pkgs.mkShell {
            buildInputs = [ toolbox ];
            
            shellHook = ''
              echo "OpenFOAM 开发工具箱环境已设置"
            '';
          };
        } // {
          # 为每个 OpenFOAM 版本创建对应的 solids4foam 环境
          "solids4foam-9" = makeSolids4FoamDevShell "openfoam-9";
          "solids4foam-10" = makeSolids4FoamDevShell "openfoam-10";
          "solids4foam-11" = makeSolids4FoamDevShell "openfoam-11";
        }
      );

      defaultDevShell = forAllSystems (system: self.devShells.${system}.default);
    };
} 