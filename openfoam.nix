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
}:

with pkgs;

stdenv.mkDerivation rec {
  version = lib.removePrefix "OpenFOAM-" versionInfo.OpenFOAM.name;
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
    sed -ie 's|METIS_ARCH_PATH=.*$|METIS_ARCH_PATH=${metis}|' etc/config.sh/metis
    sed -ie 's|SCOTCH_ARCH_PATH=.*$|SCOTCH_ARCH_PATH=${scotch}|' etc/config.sh/scotch
    sed -ie "s|CHANGEME|$out|" etc/bashrc

    # Reproduce the hirearchy with ThirdParty in the out dir
    mkdir -p $out/${versionInfo.OpenFOAM.name}
    cp -r ./* $out/${versionInfo.OpenFOAM.name}
    mkdir -p $out/${versionInfo.ThirdParty.name}
    cp -r ../${versionInfo.ThirdParty.name}/* $out/${versionInfo.ThirdParty.name}
    echo "All source copied!"
    cd $out/${versionInfo.OpenFOAM.name}

    source etc/bashrc
    echo Build dir is: $WM_PROJECT_DIR

    # Fix compilation issues
    chmod +w ../${versionInfo.ThirdParty.name}/scotch_*/src

    export WM_NCOMPPROCS="$NIX_BUILD_CORES"
    export PATH=$PATH:$PWD/wmake
    patchShebangs --build $PWD

    # Enable ccache
    export CCACHE_BASEDIR=$PWD
    ./Allwmake
  '';

  # stick etc, bin, and platforms under lib/OpenFOAM-${version}
  # fill bin proper up with wrappers that source etc/bashrc for everything in platform/$WM_OPTIONS/bin
  # add -mpi suffixed versions that calls proper mpirun for those with libPstream.so depencies too
  installPhase = ''
    echo "copying etc, bin, and platforms directories to $out/lib/${versionInfo.OpenFOAM.name}"
    cd $out/${versionInfo.OpenFOAM.name}
    mkdir -p "$out/lib/${versionInfo.OpenFOAM.name}"
    cp -at "$out/lib/${versionInfo.OpenFOAM.name}" etc bin platforms tutorials applications
    echo "creating a bin of wrapped binaries from $out/lib/${versionInfo.OpenFOAM.name}/platforms/$WM_OPTIONS/bin"
    for program in "$out/lib/${versionInfo.OpenFOAM.name}/{platforms/$WM_OPTIONS,tools}/bin/"*; do
      makeWrapper "$program" "$out/bin/''${program##*/}" \
        --run "source \"$out/lib/${versionInfo.OpenFOAM.name}/etc/bashrc\"" \
        --run "PATH=$PATH:${coreutils}/bin:${findutils}/bin:${gnused}/bin"
      if readelf -d "$program" | fgrep -q libPstream.so; then
        makeWrapper "${openmpi}/bin/mpirun" "$out/bin/''${program##*/}-mpi" \
          --run "[ -r processor0 ] || { echo \"Case is not currently decomposed, see decomposePar documentation\"; exit 1; }" \
          --run "extraFlagsArray+=(-n \"\$(ls -d processor* | wc -l)\" \"$out/bin/''${program##*/}\" -parallel)" \
          --run "source \"$out/lib/${versionInfo.OpenFOAM.name}/etc/bashrc\""
      fi
    done
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
