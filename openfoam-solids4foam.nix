{ lib
, stdenv
, fetchFromGitHub
, fetchurl
, openfoam
, bigarray
, parmetis
, scotch
, petsc
, boost
, mpi
, openmpi
}:

let
  # 读取 solids4foam_versions.json
  solids4foamVersions = builtins.fromJSON (builtins.readFile ./solids4foam_versions.json);

  # 从 openfoam 包名中获取版本号
  ofVersion = builtins.substring 9 2 openfoam.name;

  # 根据 OpenFOAM 版本选择对应的 solids4foam 配置
  versionKey = "OpenFOAM${ofVersion}";
  versionInfo = solids4foamVersions.${versionKey};

  # 预下载 eigen3
  eigen3 = fetchurl {
    url = "https://gitlab.com/libeigen/eigen/-/archive/3.3.7/eigen-3.3.7.tar.gz";
    sha256 = "sha256-1W+62Vq/mT+K9ghIRynj2H72Ed2FszgKi60dXLw3Olc=";
  };
in

stdenv.mkDerivation rec {
  pname = "solids4foam";
  version = versionInfo.rev;

  src = fetchFromGitHub {
    inherit (versionInfo) owner repo rev sha256;
    name = "solids4foam-${version}";
  };

  nativeBuildInputs = [
    openfoam
    boost
    mpi
    openmpi
    scotch
    petsc
    parmetis
  ];

  dontConfigure = true;
  dontFixCmake = true;

  buildPhase = ''
    # 设置 OpenFOAM 环境
    source ${openfoam}/OpenFOAM-${ofVersion}/etc/bashrc
    export FOAM_USER_LIBBIN="$PWD/platforms/$WM_OPTIONS/lib"

    # 创建 ThirdParty/eigen3 目录并解压 eigen3
    mkdir -p ThirdParty/eigen3
    tar xf ${eigen3} -C ThirdParty/eigen3 --strip-components=1

    patchShebangs --build $PWD
    ./Allwmake -j
  '';

  installPhase = ''
    # 创建目标目录
    mkdir -p $out/lib
    mkdir -p $out/bin
    
    # 复制编译后的库文件
    if [ -d "platforms/$WM_OPTIONS/lib" ]; then
      cp -r platforms/$WM_OPTIONS/lib/* $out/lib/
    fi
    
    # 复制编译后的可执行文件
    if [ -d "platforms/$WM_OPTIONS/bin" ]; then
      cp -r platforms/$WM_OPTIONS/bin/* $out/bin/
    fi
    
    # 复制脚本文件
    if [ -d "bin" ]; then
      cp -r bin/* $out/bin/
    fi
  '';

  propagatedBuildInputs = [
    openfoam
    boost
    mpi
    openmpi
    scotch
    petsc
    parmetis
  ];

  meta = with lib; {
    description = "Solids4Foam is an OpenFOAM® based toolbox for solid mechanics and fluid-solid interaction";
    homepage = "https://openfoamwiki.net/index.php/Extension:Solids4Foam";
    license = licenses.gpl3;
    platforms = platforms.unix;
  };
} 