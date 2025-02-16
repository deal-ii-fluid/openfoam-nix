{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  openfoam,
  precice,
  openmpi,
  debugMode ? false,
  enableTimings ? false,
}:

let
  # 读取 adapter_versions.json
  adapterVersions = builtins.fromJSON (builtins.readFile ./adapter_versions.json);

  # 从 openfoam 包名中获取版本号
  ofVersion = builtins.substring 9 2 openfoam.name;

  # 根据 OpenFOAM 版本选择对应的 adapter 配置
  versionKey = "OpenFOAM${ofVersion}";
  versionInfo = adapterVersions.${versionKey};
in

stdenv.mkDerivation rec {
  pname = "precice-openfoam-adapter";
  version = versionInfo.rev;

  src = fetchFromGitHub {
    inherit (versionInfo) rev hash;
    owner = "deal-ii-fluid";
    repo = "openfoam-adapter";
  };

  nativeBuildInputs = [
    pkg-config
    openfoam
    precice
    openmpi
  ];

  buildPhase = ''
    # 设置 OpenFOAM 环境
    source ${openfoam}/OpenFOAM-${ofVersion}/etc/bashrc

    # 设置构建环境
    export FOAM_USER_LIBBIN="$PWD/platforms/$WM_OPTIONS/lib"
    export ADAPTER_TARGET_DIR="$FOAM_USER_LIBBIN"
    export ADAPTER_PREP_FLAGS="${lib.optionalString debugMode "-DADAPTER_DEBUG_MODE"} ${lib.optionalString enableTimings "-DADAPTER_ENABLE_TIMINGS"}"

    # 创建目标目录
    mkdir -p $ADAPTER_TARGET_DIR

    # 确保 MPI 库可用
    export FOAM_MPI=openmpi-system
    export FOAM_MPI_LIBBIN=$FOAM_LIBBIN/$FOAM_MPI
    export LD_LIBRARY_PATH="${openfoam}/OpenFOAM-${ofVersion}/platforms/$WM_OPTIONS/lib:${openfoam}/OpenFOAM-${ofVersion}/platforms/$WM_OPTIONS/lib/$FOAM_MPI:$LD_LIBRARY_PATH"
   
    patchShebangs --build $PWD
    # 运行构建
    ./Allwmake -j -q
  '';

  installPhase = ''
    mkdir -p $out/lib
    # 复制主库文件
    cp platforms/$WM_OPTIONS/lib/libpreciceAdapterFunctionObject.so $out/lib/
    
    # 复制 libPstream.so
    cp ${openfoam}/OpenFOAM-${ofVersion}/platforms/$WM_OPTIONS/lib/openmpi-system/libPstream.so $out/lib/
  '';

  # 添加运行时依赖
  propagatedBuildInputs = [
    openfoam
    precice
    openmpi
  ];

  # 设置 RPATH
  postFixup = let
    ofLibDir = "${openfoam}/OpenFOAM-${ofVersion}/platforms/linuxArm64GccDPInt32Opt/lib";
  in ''
    patchelf --set-rpath "\$ORIGIN:${ofLibDir}:${lib.makeLibraryPath propagatedBuildInputs}" \
      $out/lib/libpreciceAdapterFunctionObject.so
  '';

  meta = {
    description = "OpenFOAM adapter for preCICE coupling library";
    homepage = "https://precice.org/adapter-openfoam-overview.html";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ ];
  };
}
