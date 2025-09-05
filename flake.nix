{
  description = "Inngest libvirt - VM provisioner";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    # Pin to a revision that includes libvirt 9.0.0
    nixpkgs-libvirt-9 = {
      url = "github:nixos/nixpkgs/23.05";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-libvirt-9, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # Import libvirt 9.0.0 from pinned nixpkgs revision
        pkgs-libvirt-9 = import nixpkgs-libvirt-9 {
          inherit system;
          config.allowUnfree = true;
        };
        libvirt_9_0_0 = pkgs-libvirt-9.libvirt;

        libvirtSrcPrepared = pkgs.stdenv.mkDerivation {
          name = "libvirt-src-prepared";
          src = libvirt_9_0_0.src;

          nativeBuildInputs = with pkgs;
            [ meson ninja pkg-config gnumake gnused gnugrep ] ++ libvirt_9_0_0.nativeBuildInputs;

          buildInputs = libvirt_9_0_0.buildInputs;

          configurePhase = ''
            # Create GNU tool symlinks since libvirt expects them
            mkdir -p $TMPDIR/bin
            ln -s ${pkgs.gnumake}/bin/make $TMPDIR/bin/gmake
            ln -s ${pkgs.gnused}/bin/sed $TMPDIR/bin/gsed
            ln -s ${pkgs.gnugrep}/bin/grep $TMPDIR/bin/ggrep
            export PATH="$TMPDIR/bin:$PATH"
            meson setup build
          '';

          buildPhase =
            "true"; # Skip actual build, we just need the prepared source

          installPhase = ''
            mkdir -p $out
            # Copy source files but exclude broken symlinks from build directory
            find . -name 'build' -prune -o -type f -print | xargs -I {} cp --parents {} $out/
            # Copy the meson build configuration
            cp -r build/meson-info $out/build/ 2>/dev/null || true
            cp -r build/meson-logs $out/build/ 2>/dev/null || true
            cp build/build.ninja $out/build/ 2>/dev/null || true
            cp build/compile_commands.json $out/build/ 2>/dev/null || true
          '';
        };

      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            go
            golangci-lint
            gotests
            gomodifytags
            gore
            gotools

            # LSPs
            gopls

            # Tools
            claude-code
            libvirt_9_0_0
          ];

          shellHook = ''
            export GOBIN=$PWD/bin
            export PATH="$PATH:$GOBIN:$HOME/go/bin"
            export LIBVIRT_SOURCE=${libvirtSrcPrepared}
          '';
        };
      });
}
