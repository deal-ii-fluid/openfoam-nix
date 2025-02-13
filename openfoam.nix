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
}:
stdenv.mkDerivation rec {
  version = "11";
  name = "openfoam-${version}";

  srcs = [
    (fetchFromGitHub {
      owner = "OpenFOAM";
      repo = "OpenFOAM-${version}";
      rev = "c46b322d5bf43cdd6a9dd99737a8798df290c537";
      sha256 = "sha256-3g5pqgsKvbMCf5Yrbo0B38ns4XZsq1/fl7ht1YLs1vs=";
      name = "OpenFOAM-${version}";
    })
    (fetchFromGitHub {
      owner = "OpenFOAM";
      repo = "ThirdParty-${version}";
      rev = "f379fadb73ceb5cb92d5d5379eb64b1dc956ab4f";
      sha256 = "sha256-HtyKoNtjT119aun/VS3xrtGMt2d2h3bHQK10shhNEyU=";
      name = "ThirdParty-${version}";
    })
  ];

  # FIXME using $out in the bashrc breaks the runtime bashrc. Use the real path in the store instead
  patches = [ ./fix-config.patch ];
  sourceRoot = "OpenFOAM-${version}";


  buildPhase = ''
    sed -ie 's|METIS_ARCH_PATH=.*$|METIS_ARCH_PATH=${metis}|' etc/config.sh/metis
    sed -ie 's|SCOTCH_ARCH_PATH=.*$|SCOTCH_ARCH_PATH=${scotch}|' etc/config.sh/scotch
    sed -ie "s|CHANGEME|$out|" etc/bashrc

    # Reproduce the hirearchy with ThirdParty in the out dir
    mkdir -p $out/OpenFOAM-${version}
    cp -r ./* $out/OpenFOAM-${version}
    mkdir -p $out/ThirdParty-${version}
    cp -r ../ThirdParty-${version}/* $out/ThirdParty-${version}
    echo "All source copied!"
    cd $out/OpenFOAM-${version}

    source etc/bashrc
    echo Build dir is: $WM_PROJECT_DIR

    # Fix compilation issues
    chmod +w ../ThirdParty-${version}/scotch_*/src

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
    echo "copying etc, bin, and platforms directories to $out/lib/OpenFOAM-${version}"
    cd $out/OpenFOAM-${version}
    mkdir -p "$out/lib/OpenFOAM-${version}"
    cp -at "$out/lib/OpenFOAM-${version}" etc bin platforms tutorials applications
    echo "creating a bin of wrapped binaries from $out/lib/OpenFOAM-${version}/platforms/$WM_OPTIONS/bin"
    for program in "$out/lib/OpenFOAM-${version}/{platforms/$WM_OPTIONS,tools}/bin/"*; do
      makeWrapper "$program" "$out/bin/''${program##*/}" \
        --run "source \"$out/lib/OpenFOAM-${version}/etc/bashrc\""
        --run "PATH=$PATH:${coreutils}/bin:${findutils}/bin:${gnused}/bin"
      if readelf -d "$program" | fgrep -q libPstream.so; then
        makeWrapper "${openmpi}/bin/mpirun" "$out/bin/''${program##*/}-mpi" \
          --run "[ -r processor0 ] || { echo \"Case is not currently decomposed, see decomposePar documentation\"; exit 1; }" \
          --run "extraFlagsArray+=(-n \"\$(ls -d processor* | wc -l)\" \"$out/bin/''${program##*/}\" -parallel)" \
          --run "source \"$out/lib/OpenFOAM-${version}/etc/bashrc\""
      fi
    done
  '';

  nativeBuildInputs = [
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
    # Avoid ZIP unpack error because of zeroed timestamp
    ensureNewerSourcesForZipFilesHook
  ];

  meta = with lib; {
    homepage = https://www.openfoam.org;
    description = "Free open-source CFD software";
    platforms = platforms.linux;
    license = licenses.gpl3;
  };
}
