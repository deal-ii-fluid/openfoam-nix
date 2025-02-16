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
    owner = "precice";
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
    export ADAPTER_PREP_FLAGS="${lib.optionalString debugMode "-DADAPTER_DEBUG_MODE"} ${lib.optionalString enableTimings "-DADAPTER_ENABLE_TIMINGS"}"

    # 运行构建
    ./Allwmake -j -q
  '';

  installPhase = ''
    mkdir -p $out/{lib,share}
    cp /tmp/OpenFOAM-${ofVersion}/platforms/$WM_OPTIONS/lib/libpreciceAdapterFunctionObject.so $out/lib/
  '';

  meta = {
    description = "OpenFOAM adapter for preCICE coupling library";
    homepage = "https://precice.org/adapter-openfoam-overview.html";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ ];
  };
}
