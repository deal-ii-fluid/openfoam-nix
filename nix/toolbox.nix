{ lib
, buildEnv
, gcc
, cmake
, gnumake
, git
, wget
, gdb
, valgrind
, ninja
, pkg-config
, python3
, binutils
, file
, which
}:

buildEnv {
  name = "openfoam-toolbox";
  paths = [
    # 编译工具
    gcc
    cmake
    gnumake
    ninja
    pkg-config
    binutils

    # 版本控制
    git

    # 下载工具
    wget

    # 调试工具
    gdb
    valgrind

    # 实用工具
    python3
    file
    which
  ];

  meta = with lib; {
    description = "Common development tools for OpenFOAM";
    license = licenses.mit;
    platforms = platforms.unix;
  };
} 