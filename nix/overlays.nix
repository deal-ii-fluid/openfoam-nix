final: prev: {
  ccacheWrapper = prev.ccacheWrapper.override {
    extraConfig = ''
      export CCACHE_COMPRESS=1
      export CCACHE_DIR="/tmp/ccache"
      export CCACHE_UMASK=007
      export CCACHE_COMPILERCHECK=content
      mkdir -p "$CCACHE_DIR"
    '';
  };

  openfoam11 = final.callPackage ./openfoam.nix { 
    stdenv = prev.ccacheStdenv; 
  };
}
