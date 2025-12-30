{
  description = "UE4SS CPP Template environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, fenix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        # Configure Rust toolchain with MSVC target support
        rustToolchain = with fenix.packages.${system}; combine [
          minimal.toolchain
          targets.x86_64-pc-windows-msvc.latest.rust-std
        ];

        # Dependencies required for cross-compilation
        crossCompileBuildInputs = with pkgs; [
          cmake
          ninja
          llvmPackages.clang-unwrapped
          llvmPackages.bintools
          llvmPackages.llvm 
          rustToolchain
          git
          xwin
          openssl
          pkg-config
          libiconv
          python3
          lld
        ];

        # Environment variables required for the build script and headers
        crossCompileEnv = ''
          export CLANG_UNWRAPPED_BIN="${pkgs.llvmPackages.clang-unwrapped}/bin/clang"
          export CLANG_CL_UNWRAPPED_BIN="${pkgs.llvmPackages.clang-unwrapped}/bin/clang-cl"
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = crossCompileBuildInputs;
          
          shellHook = ''
            echo "Environment loaded."
            ${crossCompileEnv}
            echo "Using unwrapped clang at: $CLANG_UNWRAPPED_BIN"
          '';
        };

        packages.default = pkgs.writeShellApplication {
          name = "setup-cross-compile";
          runtimeInputs = crossCompileBuildInputs;
          text = ''
            # Setup environment variables
            ${crossCompileEnv}
            
            # Source the original script content
            ${builtins.readFile ./setup_cross_compile.sh}
          '';
        };

        # Alias for explicit naming
        packages.setup = self.packages.${system}.default;

        packages.build = pkgs.writeShellApplication {
          name = "build-cross";
          runtimeInputs = crossCompileBuildInputs;
          text = ''
            # Setup environment variables
            ${crossCompileEnv}
            
            # Run cmake build with any extra args passed through
            cmake --build build-cross "$@"
          '';
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
        };

        apps.setup = self.apps.${system}.default;

        apps.build = flake-utils.lib.mkApp {
          drv = self.packages.${system}.build;
        };
      }
    );
}
