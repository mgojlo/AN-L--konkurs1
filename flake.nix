{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  } @ inputs: let
    zig-version = "0.13.0";
  in
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            inputs.zig-overlay.overlays.default
          ];
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.wayland-scanner
            pkgs.wayland
            pkgs.libxkbcommon
            pkgs.xorg.libX11
            pkgs.xorg.libXcursor
            pkgs.xorg.libXrender
            pkgs.xorg.libXrandr
            pkgs.xorg.libXinerama
            pkgs.xorg.libXi
            pkgs.xorg.libXfixes
            pkgs.xorg.libXext
            pkgs.libGL
            pkgs.glfw3
            pkgs.libdrm
            pkgs.mesa
          ];
          nativeBuildInputs = [
            pkgs.pkg-config
            pkgs.zigpkgs."${zig-version}"
          ];
        };
      }
    );
}
