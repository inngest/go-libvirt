{
  description = "Inngest libvirt - VM provisioner";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        libvirtSrcPrepared = pkgs.stdenv.mkDerivation {
          name = "libvirt-src-prepared";
          src = pkgs.libvirt.src;

          nativeBuildInputs = with pkgs;
            [ meson ninja pkg-config ] ++ pkgs.libvirt.nativeBuildInputs;

          buildInputs = pkgs.libvirt.buildInputs;

          configurePhase = ''
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
            libvirt
          ];

          shellHook = ''
            export GOBIN=$PWD/bin
            export PATH="$PATH:$GOBIN:$HOME/go/bin"
            export LIBVIRT_SOURCE=${libvirtSrcPrepared}
          '';
        };
      });
}
