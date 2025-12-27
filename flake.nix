{
  description = "Rust cross-compile";

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
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        targetWin = "x86_64-pc-windows-gnu";

        pkgsCrossWin = pkgs.pkgsCross.mingwW64;
        ccWin = pkgsCrossWin.stdenv.cc;
        pthreadsWin = pkgsCrossWin.windows.pthreads;

        libpthread-workaround = pkgs.runCommand "libpthread-workaround" {} ''
          mkdir -p $out/lib
          ln -s ${pthreadsWin}/lib/libwinpthread.a $out/lib/libpthread.a
        '';

        toolchain = with fenix.packages.${system};
          combine [
            minimal.cargo
            minimal.rustc
            targets.${system}.latest.rust-std
            targets.${targetWin}.latest.rust-std
          ];

        naersk-lib = naersk.lib.${system}.override {
          cargo = toolchain;
          rustc = toolchain;
        };

        commonAttrs = {
          src = ./.;
        };
      in {
        packages = {
          default = naersk-lib.buildPackage (commonAttrs
            // {
              strictDeps = true;
            });

          windows = naersk-lib.buildPackage (commonAttrs
            // {
              CARGO_BUILD_TARGET = targetWin;
              CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = "${ccWin}/bin/${ccWin.targetPrefix}cc";
              RUSTFLAGS = "-L native=${libpthread-workaround}/lib";
              depsBuildBuild = [ccWin];
              buildInputs = [pthreadsWin];
            });
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [toolchain];

          buildInputs = [pthreadsWin];

          CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = "${ccWin}/bin/${ccWin.targetPrefix}cc";

          RUSTFLAGS = "-L native=${libpthread-workaround}/lib";

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib];
        };
      }
    );
}
