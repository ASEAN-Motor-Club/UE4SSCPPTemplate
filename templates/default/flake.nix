{
  description = "UE4SS C++ Mod - Created from template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    ue4ss-cross.url = "github:ASEAN-Motor-Club/UE4SSCPPTemplate";
  };

  outputs = inputs@{ flake-parts, ue4ss-cross, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { system, ... }:
        let
          lib = ue4ss-cross.lib.${system};
        in
        {
          # Development shell with all cross-compile tools
          devShells.default = lib.mkDevShell {};

          # Configure script (run with `nix run .#configure`)
          apps.configure = {
                         type = "app";
                         program = "${lib.mkConfigureScript {
                           modName = "MyMod";
                         }}/bin/MyMod-configure";
                       };

          # Build script (run with `nix run .#build`)
          apps.build = {
            type = "app";
            program = "${lib.mkBuildScript {
              modName = "MyMod";
            }}/bin/MyMod-build";
          };

          # Package script (run with `nix run .#package`)
          apps.package = {
            type = "app";
            program = "${lib.mkPackageScript {
              modName = "MyMod";
            }}/bin/MyMod-package";
          };

          # Default to build
          apps.default = apps.build;
        };
    };
}
