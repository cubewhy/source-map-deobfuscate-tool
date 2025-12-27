{
  description = "A Nix-flake-based Rust development environment";

  inputs = {
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    fenix,
    flake-utils,
    naersk,
    nixpkgs,
  }:
    flake-utils.lib.eachDefaultSystem (system: {
      packages.default = let
        pkgs = nixpkgs.legacyPackages.${system};
        target = "x86_64-pc-windows-gnu";

        # Cross-compilation toolchain components
        pkgsCross = pkgs.pkgsCross.mingwW64;
        cc = pkgsCross.stdenv.cc;

        # Workaround: Rust expects libpthread.a, but MinGW provides libwinpthread.a
        # We create a derivation that symlinks the library to the expected name.
        pthreads = pkgsCross.windows.pthreads;
        libpthread-workaround = pkgs.runCommand "libpthread-workaround" {} ''
          mkdir -p $out/lib
          ln -s ${pthreads}/lib/libwinpthread.a $out/lib/libpthread.a
        '';

        toolchain = with fenix.packages.${system};
          combine [
            minimal.cargo
            minimal.rustc
            targets.${target}.latest.rust-std
          ];
      in
        (naersk.lib.${system}.override {
          cargo = toolchain;
          rustc = toolchain;
        }).buildPackage {
          src = ./.;

          CARGO_BUILD_TARGET = target;
          CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = "${cc}/bin/${cc.targetPrefix}cc";

          # Add the workaround library to the search path
          RUSTFLAGS = "-L native=${libpthread-workaround}/lib";

          # Ensure the compiler and standard windows libs are available
          depsBuildBuild = [cc];
          buildInputs = [pthreads];
        };
    });
}
