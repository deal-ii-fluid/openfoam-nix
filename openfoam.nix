{ lib
, stdenv
, fetchFromGitHub
, fetchurl
, makeWrapper
, ensureNewerSourcesForZipFilesHook
  # Build deps
, flex
, bison
, zlib
, boost
, openmpi
, readline
, gperftools
, metis
, scotch
  # Runtime dependencies
, coreutils
, gnused
, findutils
, versionInfo
, pkgs
, writeScript
}:

with pkgs;

let
  # 从 name 中提取版本号
  version = lib.removePrefix "OpenFOAM-" versionInfo.OpenFOAM.name;
in
stdenv.mkDerivation rec {
  pname = "openfoam";
  inherit version;
  name = "openfoam-${version}";

  srcs = [
    (fetchFromGitHub {
      owner = versionInfo.OpenFOAM.owner;
      repo = versionInfo.OpenFOAM.repo;
      rev = versionInfo.OpenFOAM.rev;
      sha256 = lib.removePrefix "sha256-" versionInfo.OpenFOAM.sha256;
      name = versionInfo.OpenFOAM.name;
    })
    (fetchFromGitHub {
      owner = versionInfo.ThirdParty.owner;
      repo = versionInfo.ThirdParty.repo;
      rev = versionInfo.ThirdParty.rev;
      sha256 = lib.removePrefix "sha256-" versionInfo.ThirdParty.sha256;
      name = versionInfo.ThirdParty.name;
    })
  ];

  # FIXME using $out in the bashrc breaks the runtime bashrc. Use the real path in the store instead
  patches = [ ./fix-config.patch ];
  sourceRoot = versionInfo.OpenFOAM.name;


  buildPhase = ''
    # 首先修改配置文件
    sed -ie 's|METIS_ARCH_PATH=.*$|METIS_ARCH_PATH=${metis}|' etc/config.sh/metis
    sed -ie 's|SCOTCH_ARCH_PATH=.*$|SCOTCH_ARCH_PATH=${scotch}|' etc/config.sh/scotch
    sed -ie "s|CHANGEME|$out|" etc/bashrc

    # 修改 etc/bashrc，替换所有用户目录相关的设置
    sed -ie 's|\$HOME/\$WM_PROJECT/\$USER|/tmp/OpenFOAM|g' etc/bashrc
    # 注释掉原有的 WM_PROJECT_USER_DIR 设置
    sed -ie 's|^export WM_PROJECT_USER_DIR=.*$|# &  # Commented out by nix build|' etc/bashrc
    # 在文件末尾强制设置用户目录
    echo "export WM_PROJECT_USER_DIR=/tmp/OpenFOAM-${version}" >> etc/bashrc
    echo "export FOAM_USER_APPBIN=/tmp/OpenFOAM-${version}/platforms/\$WM_OPTIONS/bin" >> etc/bashrc
    echo "export FOAM_USER_LIBBIN=/tmp/OpenFOAM-${version}/platforms/\$WM_OPTIONS/lib" >> etc/bashrc

    # 创建所有必需的目录
    mkdir -p $out/bin
    mkdir -p $out/${versionInfo.OpenFOAM.name}
    mkdir -p $out/${versionInfo.ThirdParty.name}
    
    # 复制文件
    cp -r ./* $out/${versionInfo.OpenFOAM.name}
    cp -r ../${versionInfo.ThirdParty.name}/* $out/${versionInfo.ThirdParty.name}
    
    cd $out/${versionInfo.OpenFOAM.name}

    # 修复符号链接
    if [ -L tutorials/mesh/snappyHexMesh/iglooWithFridges ]; then
      rm tutorials/mesh/snappyHexMesh/iglooWithFridges
    fi

    # 设置构建环境
    export HOME=/tmp  # 确保构建时 HOME 指向 /tmp
    source etc/bashrc
    
    chmod +w ../${versionInfo.ThirdParty.name}/scotch_*/src
    
    export WM_NCOMPPROCS="$NIX_BUILD_CORES"
    export PATH=$PATH:$PWD/wmake
    patchShebangs --build $PWD
    
    export CCACHE_BASEDIR=$PWD
    ./Allwmake -j -q
  '';

  # stick etc, bin, and platforms under lib/OpenFOAM-${version}
  # fill bin proper up with wrappers that source etc/bashrc for everything in platform/$WM_OPTIONS/bin
  # add -mpi suffixed versions that calls proper mpirun for those with libPstream.so depencies too
  installPhase = ''
    echo "=== Starting installPhase for OpenFOAM-${version} ==="
    
    echo "Copying directories to $out/lib/OpenFOAM-${version}"
    cd $out/${versionInfo.OpenFOAM.name}
    mkdir -p "$out/lib/${versionInfo.OpenFOAM.name}"
    cp -at "$out/lib/${versionInfo.OpenFOAM.name}" etc bin platforms tutorials applications
    
    echo "Creating set-openfoam-vars scripts in $out/bin"
    mkdir -p "$out/bin"
    
    # 创建 bash 版本
    echo "Writing bash version of set-openfoam-vars"
    cat > "$out/bin/set-openfoam-vars" << EOL
#!${pkgs.bash}/bin/bash

# 基础 OpenFOAM 环境变量
export FOAM_API=${lib.substring 0 2 version}
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
export WM_ARCH=linuxArm64
export WM_OPTIONS="\$WM_ARCH\$WM_COMPILER\$WM_PRECISION_OPTION\$WM_LABEL_OPTION\$WM_COMPILE_OPTION"

# 主要目录路径
export WM_PROJECT_DIR=$out/${versionInfo.OpenFOAM.name}
export WM_PROJECT_USER_DIR="/tmp/OpenFOAM-${version}"
export WM_THIRD_PARTY_DIR=$out/${versionInfo.ThirdParty.name}

# OpenFOAM 源代码和应用程序路径
export FOAM_APP="\$WM_PROJECT_DIR/applications"
export FOAM_SRC="\$WM_PROJECT_DIR/src"
export FOAM_SOLVERS="\$FOAM_APP/solvers"
export FOAM_UTILITIES="\$FOAM_APP/utilities"
export FOAM_ETC="\$WM_PROJECT_DIR/etc"
export FOAM_TUTORIALS="\$WM_PROJECT_DIR/tutorials"

# 二进制和库文件路径
export FOAM_APPBIN="\$WM_PROJECT_DIR/platforms/\$WM_OPTIONS/bin"
export FOAM_LIBBIN="\$WM_PROJECT_DIR/platforms/\$WM_OPTIONS/lib"
export FOAM_USER_LIBBIN="\$WM_PROJECT_USER_DIR/platforms/\$WM_OPTIONS/lib"
export FOAM_USER_APPBIN="\$WM_PROJECT_USER_DIR/platforms/\$WM_OPTIONS/bin"

# wmake 设置
export WM_DIR="\$WM_PROJECT_DIR/wmake"
export WM_NCOMPPROCS=\$(${pkgs.coreutils}/bin/nproc)

# PATH 设置
export PATH="${openmpi}/bin:\$PATH"
export PATH="\$WM_DIR:\$PATH"
export PATH="\$WM_PROJECT_DIR/bin:\$PATH"
export PATH="\$FOAM_APPBIN:\$PATH"

# LD_LIBRARY_PATH 设置
export LD_LIBRARY_PATH="${openmpi}/lib:\$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH="\$WM_PROJECT_DIR/platforms/\$WM_OPTIONS/lib:\$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH="\$WM_THIRD_PARTY_DIR/platforms/\$WM_OPTIONS/lib:\$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH="\$FOAM_USER_LIBBIN:\$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH="\$FOAM_LIBBIN:\$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH="\$FOAM_LIBBIN/dummy:\$LD_LIBRARY_PATH"

# 创建用户目录（根据环境选择合适的位置）
${pkgs.coreutils}/bin/mkdir -p "$WM_PROJECT_USER_DIR"
${pkgs.coreutils}/bin/mkdir -p "$FOAM_USER_APPBIN"
${pkgs.coreutils}/bin/mkdir -p "$FOAM_USER_LIBBIN"
EOL

    # 创建 fish 版本
    echo "Writing fish version of set-openfoam-vars"
    cat > "$out/bin/set-openfoam-vars.fish" << EOL
#!/usr/bin/env fish

# 基础 OpenFOAM 环境变量
set -gx FOAM_API ${lib.substring 0 2 version}
set -gx WM_PROJECT OpenFOAM
set -gx WM_PROJECT_VERSION ${version}
set -gx FOAM_MPI sys-openmpi
set -gx WM_MPLIB SYSTEMOPENMPI

# 编译器和构建选项
set -gx WM_COMPILER Gcc
set -gx WM_COMPILER_TYPE system
set -gx WM_COMPILE_OPTION Opt
set -gx WM_LABEL_OPTION Int32
set -gx WM_LABEL_SIZE 32
set -gx WM_PRECISION_OPTION DP

# 架构和选项设置
set -gx WM_ARCH linuxArm64
set -gx WM_OPTIONS "\$WM_ARCH\$WM_COMPILER\$WM_PRECISION_OPTION\$WM_LABEL_OPTION\$WM_COMPILE_OPTION"

# 主要目录路径
set -gx WM_PROJECT_DIR $out/${versionInfo.OpenFOAM.name}
set -gx WM_PROJECT_USER_DIR "/tmp/OpenFOAM-${version}"
set -gx WM_THIRD_PARTY_DIR $out/${versionInfo.ThirdParty.name}

# OpenFOAM 源代码和应用程序路径
set -gx FOAM_APP "\$WM_PROJECT_DIR/applications"
set -gx FOAM_SRC "\$WM_PROJECT_DIR/src"
set -gx FOAM_SOLVERS "\$FOAM_APP/solvers"
set -gx FOAM_UTILITIES "\$FOAM_APP/utilities"
set -gx FOAM_ETC "\$WM_PROJECT_DIR/etc"
set -gx FOAM_TUTORIALS "\$WM_PROJECT_DIR/tutorials"

# 二进制和库文件路径
set -gx FOAM_APPBIN "\$WM_PROJECT_DIR/platforms/\$WM_OPTIONS/bin"
set -gx FOAM_LIBBIN "\$WM_PROJECT_DIR/platforms/\$WM_OPTIONS/lib"
set -gx FOAM_USER_LIBBIN "\$WM_PROJECT_USER_DIR/platforms/\$WM_OPTIONS/lib"
set -gx FOAM_USER_APPBIN "\$WM_PROJECT_USER_DIR/platforms/\$WM_OPTIONS/bin"

# wmake 设置
set -gx WM_DIR "\$WM_PROJECT_DIR/wmake"
set -gx WM_NCOMPPROCS (${pkgs.coreutils}/bin/nproc)

# PATH 设置
set -gx PATH "${openmpi}/bin" \$PATH
set -gx PATH "\$WM_DIR" \$PATH
set -gx PATH "\$WM_PROJECT_DIR/bin" \$PATH
set -gx PATH "\$FOAM_APPBIN" \$PATH

# LD_LIBRARY_PATH 设置
set -gx LD_LIBRARY_PATH "${openmpi}/lib" \$LD_LIBRARY_PATH
set -gx LD_LIBRARY_PATH "\$WM_PROJECT_DIR/platforms/\$WM_OPTIONS/lib" \$LD_LIBRARY_PATH
set -gx LD_LIBRARY_PATH "\$WM_THIRD_PARTY_DIR/platforms/\$WM_OPTIONS/lib" \$LD_LIBRARY_PATH
set -gx LD_LIBRARY_PATH "\$FOAM_USER_LIBBIN" \$LD_LIBRARY_PATH
set -gx LD_LIBRARY_PATH "\$FOAM_LIBBIN" \$LD_LIBRARY_PATH
set -gx LD_LIBRARY_PATH "\$FOAM_LIBBIN/dummy" \$LD_LIBRARY_PATH

# 创建用户目录（根据环境选择合适的位置）
${pkgs.coreutils}/bin/mkdir -p "$WM_PROJECT_USER_DIR"
${pkgs.coreutils}/bin/mkdir -p "$FOAM_USER_APPBIN"
${pkgs.coreutils}/bin/mkdir -p "$FOAM_USER_LIBBIN"
EOL

    echo "Making scripts executable"
    chmod +x "$out/bin/set-openfoam-vars"
    chmod +x "$out/bin/set-openfoam-vars.fish"
    
    echo "Creating wrappers for OpenFOAM binaries"
    # 修改这里：分别处理 platforms 和 tools 目录
    if [ -d "$out/lib/${versionInfo.OpenFOAM.name}/platforms/$WM_OPTIONS/bin" ]; then
      for program in "$out/lib/${versionInfo.OpenFOAM.name}/platforms/$WM_OPTIONS/bin/"*; do
        if [ -f "$program" ]; then
          echo "Creating wrapper for $program"
          makeWrapper "$program" "$out/bin/''${program##*/}" \
            --run "source \"$out/bin/set-openfoam-vars\"" \
            --run "PATH=$PATH:${coreutils}/bin:${findutils}/bin:${gnused}/bin"
          
          if readelf -d "$program" | fgrep -q libPstream.so; then
            echo "Creating MPI wrapper for $program"
            makeWrapper "${openmpi}/bin/mpirun" "$out/bin/''${program##*/}-mpi" \
              --run "[ -r processor0 ] || { echo \"Case is not currently decomposed, see decomposePar documentation\"; exit 1; }" \
              --run "extraFlagsArray+=(-n \"\$(ls -d processor* | wc -l)\" \"$out/bin/''${program##*/}\" -parallel)" \
              --run "source \"$out/bin/set-openfoam-vars\""
          fi
        fi
      done
    fi

    if [ -d "$out/lib/${versionInfo.OpenFOAM.name}/tools/bin" ]; then
      for program in "$out/lib/${versionInfo.OpenFOAM.name}/tools/bin/"*; do
        if [ -f "$program" ]; then
          echo "Creating wrapper for $program"
          makeWrapper "$program" "$out/bin/''${program##*/}" \
            --run "source \"$out/bin/set-openfoam-vars\"" \
            --run "PATH=$PATH:${coreutils}/bin:${findutils}/bin:${gnused}/bin"
        fi
      done
    fi

    echo "=== Completed installPhase for OpenFOAM-${version} ==="
  '';

  buildInputs = [
    ensureNewerSourcesForZipFilesHook
    gnumake
    m4
    makeWrapper
    flex
    bison
    zlib
    boost
    openmpi
    readline
    gperftools
    metis
    scotch
  ];

  meta = with lib; {
    homepage = https://www.openfoam.org;
    description = "Free open-source CFD software";
    platforms = platforms.linux;
    license = licenses.gpl3;
  };
}
