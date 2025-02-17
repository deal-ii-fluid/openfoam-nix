{ lib
, stdenv
, fetchFromGitHub
, openfoamPkg
}:

let
  versions = lib.importJSON ../versions/blastfoam_versions.json;
  foam = openfoamPkg;
  foamVersion = builtins.substring 9 2 foam.name;
  blastfoamVersion = versions."OpenFOAM${foamVersion}";
in

stdenv.mkDerivation rec {
  pname = "blastfoam";
  version = blastfoamVersion.rev;

  src = fetchFromGitHub {
    owner = "synthetik-technologies";
    repo = "blastfoam";
    inherit (blastfoamVersion) rev sha256;
  };

  buildInputs = [
    foam
  ];

  buildPhase = ''
    # 设置 OpenFOAM 环境变量
    source ${foam}/bin/set-openfoam-vars
    # 设置 blastfoam 环境变量并编译
    source etc/bashrc
    ./Allwmake
  '';

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/lib
    cp -r $BLAST_APPBIN/* $out/bin/
    cp -r $BLAST_LIBBIN/* $out/lib/
  '';

  meta = with lib; {
    description = "A computational fluid dynamics (CFD) toolbox for compressible flow with blast, shock waves and fluid-structure interaction";
    homepage = "https://github.com/synthetik-technologies/blastfoam";
    license = licenses.gpl3Plus;
    platforms = platforms.unix;
    maintainers = with maintainers; [ ];
  };
} 