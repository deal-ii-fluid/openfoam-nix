{
  description = "OpenFOAM Project Flake";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-2305.url = "github:NixOS/nixpkgs/nixos-23.05";
    # 添加特定版本的 nixpkgs 用于 gcc/gfortran
    nixpkgs-specific.url = "github:NixOS/nixpkgs/70bdadeb94ffc8806c0570eb5c2695ad29f0e421";
  };

  outputs = { self, nixpkgs-unstable, nixpkgs-2305, nixpkgs-specific }:
    let
      supportedSystems = [ "x86_4-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs-unstable.lib.genAttrs supportedSystems;
      overlay = import ./nix/overlays.nix;
      versions = builtins.fromJSON (builtins.readFile ./versions/versions.json);
      solids4foamVersions = builtins.fromJSON (builtins.readFile ./versions/solids4foam_versions.json);
      blastfoamVersions = builtins.fromJSON (builtins.readFile ./versions/blastfoam_versions.json);

      # 添加特定版本的 nixpkgs
      pkgs-specific = forAllSystems (system: import nixpkgs-specific {
        inherit system;
        config.allowUnfree = true;
      });

      # 添加 nixpkgs-2305
      pkgs-2305 = forAllSystems (system: import nixpkgs-2305 {
        inherit system;
        config.allowUnfree = true;
      });

      # 辅助函数：创建 precice-openfoam-adapter 包
      makePreciceAdapter = system: openfoamPkg: 
        let
          pkgs = import nixpkgs-unstable {
            inherit system;
            overlays = [ overlay ];
            config.allowUnfree = true;
          };
        in pkgs.callPackage ./nix/openfoam-adapter.nix {
          openfoam = openfoamPkg;
          precice = pkgs-2305.${system}.precice;
        };

      # 辅助函数：创建 solids4foam 包
      makeSolids4Foam = system: openfoamPkg: versionKey:
        let
          pkgs = import nixpkgs-unstable {
            inherit system;
            overlays = [ overlay ];
            config.allowUnfree = true;
          };
        in pkgs.callPackage ./nix/openfoam-solids4foam.nix {
          openfoam = openfoamPkg;
          inherit (pkgs) parmetis scotch petsc boost mpi openmpi;
        };

      # 辅助函数：创建 blastfoam 包
      makeBlastFoam = system: openfoamPkg:
        let
          pkgs = import nixpkgs-unstable {
            inherit system;
            overlays = [ overlay ];
            config.allowUnfree = true;
          };
        in pkgs.callPackage ./nix/openfoam-solver-blastfoam.nix {
          openfoamPkg = openfoamPkg;
        };

    in {
      packages = forAllSystems (system: 
        let
          pkgs = import nixpkgs-unstable {
            inherit system;
            overlays = [ overlay ];
            config.allowUnfree = true;
          };
          
          # 使用 nixpkgs-2305 的包
          pkgs-2305 = import nixpkgs-2305 {
            inherit system;
            config.allowUnfree = true;
          };
          
          # 创建工具箱包
          openfoamToolbox = pkgs.callPackage ./nix/toolbox.nix {};
          
          # 创建 calculix-adapter 包，使用特定版本的编译器和依赖
          preciceCalculixAdapter = pkgs.callPackage ./nix/calculix-adapter.nix {
            inherit (pkgs-specific.${system}) gcc gfortran spooles arpack lapack blas libyamlcpp precice openmpi pkg-config;
          };
          
          # 创建 OpenFOAM 包
          makeOpenFOAM = versionName: versionInfo:
            pkgs.callPackage ./nix/openfoam.nix {
              stdenv = pkgs.ccacheStdenv;
              versionInfo = versionInfo;
            };
          
          # 创建基础 OpenFOAM 包
          openfoamPkgs = nixpkgs-unstable.lib.mapAttrs makeOpenFOAM versions;  # 更新引用
          
          # 创建 precice-openfoam-adapter 包
          preciceAdapterPkgs = builtins.listToAttrs (map (version: {
            name = "precice-openfoam-${version}";
            value = makePreciceAdapter system openfoamPkgs."openfoam-${version}";
          }) ["9" "10" "11"]);

          # 创建 solids4foam 包
          solids4foamPkgs = builtins.listToAttrs (map (version: {
            name = "solids4foam-${version}";
            value = makeSolids4Foam system openfoamPkgs."openfoam-${version}" "OpenFOAM${version}";
          }) ["9" "10" "11"]);

          # 创建 blastfoam 包
          blastfoamPkgs = builtins.listToAttrs (map (version: {
            name = "blastfoam-${version}";
            value = makeBlastFoam system openfoamPkgs."openfoam-${version}";
          }) ["9"]);  # 暂时只支持 OpenFOAM-9
        in
          openfoamPkgs // preciceAdapterPkgs // solids4foamPkgs // blastfoamPkgs // {
            inherit openfoamToolbox preciceCalculixAdapter;
          }
      );

      defaultPackage = forAllSystems (system:
        self.packages.${system}.openfoam-11
      );

      devShells = forAllSystems (system: let
        pkgs = import nixpkgs-unstable {
          inherit system;
          overlays = [ overlay ];
          config.allowUnfree = true;
        };
        
        openfoamToolbox = self.packages.${system}.openfoamToolbox;
        preciceCalculixAdapter = self.packages.${system}.preciceCalculixAdapter;
        
        # 创建带工具箱的 OpenFOAM 开发环境
        makeDevShellWithTools = versionName: versionInfo: let
          openfoamPackage = self.packages.${system}.${versionName};
        in pkgs.mkShell {
          buildInputs = [
            openfoamPackage
            openfoamToolbox  # 添加工具箱
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
          adapterPackage = pkgs.callPackage ./nix/openfoam-adapter.nix {
            openfoam = openfoamPackage;
            precice = pkgs-2305.${system}.precice;
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
          solids4foamPackage = pkgs.callPackage ./nix/openfoam-solids4foam.nix {
            openfoam = openfoamPackage;
            inherit (pkgs) parmetis scotch petsc boost mpi openmpi;
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

        # 创建 calculix-adapter 开发环境
        makeCalculixAdapterDevShell = pkgs.mkShell {
          buildInputs = [
            preciceCalculixAdapter
          ];
          
          shellHook = ''
            echo "CalculiX-adapter 开发环境已设置"
          '';
        };

        # 创建 blastfoam 开发环境
        makeBlastFoamDevShell = versionName: let
          version = builtins.substring 9 2 versionName;
          openfoamPackage = self.packages.${system}.${versionName};
          blastfoamPackage = pkgs.callPackage ./nix/openfoam-solver-blastfoam.nix {
            openfoamPkg = openfoamPackage;
          };
        in pkgs.mkShell {
          buildInputs = with pkgs; [
            openfoamPackage
            blastfoamPackage
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
            
            # 设置 blastfoam 环境变量
            export BLAST_DIR=${blastfoamPackage}
            export LD_LIBRARY_PATH=${blastfoamPackage}/lib:$LD_LIBRARY_PATH
            
            echo "OpenFOAM-blastfoam 环境已设置:"
            echo "  WM_PROJECT_DIR = $WM_PROJECT_DIR"
            echo "  BLAST_DIR      = $BLAST_DIR"
          '';
        };

      in
        # 生成所有版本的开发环境
        (nixpkgs-unstable.lib.mapAttrs makeDevShellWithTools versions) // {
          # 为每个 OpenFOAM 版本创建对应的 precice adapter 环境
          "precice-openfoam-9" = makePreciceDevShell "openfoam-9" versions.openfoam-9;
          "precice-openfoam-10" = makePreciceDevShell "openfoam-10" versions.openfoam-10;
          "precice-openfoam-11" = makePreciceDevShell "openfoam-11" versions.openfoam-11;
          
          # 默认环境
          default = makeDevShellWithTools "openfoam-11" versions.openfoam-11;
          
          # 添加纯工具箱环境
          "openfoam-toolbox" = pkgs.mkShell {
            buildInputs = [ openfoamToolbox ];
            
            shellHook = ''
              echo "OpenFOAM 开发工具箱环境已设置"
            '';
          };
          
          # 添加 calculix-adapter 环境
          "calculix-adapter" = makeCalculixAdapterDevShell;
        } // {
          # 为每个 OpenFOAM 版本创建对应的 solids4foam 环境
          "solids4foam-9" = makeSolids4FoamDevShell "openfoam-9";
          "solids4foam-10" = makeSolids4FoamDevShell "openfoam-10";
          "solids4foam-11" = makeSolids4FoamDevShell "openfoam-11";
          # 为 OpenFOAM-9 创建 blastfoam 环境
          "blastfoam-9" = makeBlastFoamDevShell "openfoam-9";
        }
      );

      defaultDevShell = forAllSystems (system: self.devShells.${system}.default);
    };
} 