{
  description = "Zig Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs}: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    devShells.${system}.default = pkgs.mkShell {
      name = "zig-dev-env";
      buildInputs = [
        pkgs.zig
        pkgs.zls
      ];
      shellHook = ''
        echo "Zig Environment ready!"
        echo "Zig version: $(zig version)"
        export ZIG_SYSTEM_LIB_DIR=${pkgs.zig}/lib
      '';
    };
  };
}

