{
  description = "UE4SS CPP Template environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ue4ss = {
      type = "git";
      url = "https://github.com/UE4SS-RE/RE-UE4SS.git";
      submodules = true;
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, fenix, ue4ss }:
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
          export UE4SS_SOURCE_DIR="${patchedUE4SS}"
        '';

        patchedUE4SS = pkgs.stdenv.mkDerivation {
          name = "ue4ss-patched";
          src = ue4ss;
          
          phases = [ "unpackPhase" "patchPhase" "installPhase" ];
          
          patches = [ ./patches/ue4ss-cross-compile.patch ];
          
          installPhase = ''
            mkdir -p $out
            cp -r . $out
            
            # Overlay our custom proxy generator files
            mkdir -p $out/UE4SS/proxy_generator/exports
            cp ${./proxy_generator/proxy_generator.py} $out/UE4SS/proxy_generator/proxy_generator.py
            cp -r ${./proxy_generator/exports}/* $out/UE4SS/proxy_generator/exports/
          '';
        };
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

        packages.ue4ss-patched = patchedUE4SS;

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

        # Reusable library functions for external projects
        lib = {
          # The patched UE4SS source
          inherit patchedUE4SS;
          
          # Build inputs for cross-compilation
          inherit crossCompileBuildInputs;
          
          # Environment setup string
          inherit crossCompileEnv;
          
          # Create a development shell for an external mod project
          mkDevShell = { extraBuildInputs ? [] }:
            pkgs.mkShell {
              buildInputs = crossCompileBuildInputs ++ extraBuildInputs;
              shellHook = ''
                echo "UE4SS Cross-Compile Environment loaded."
                ${crossCompileEnv}
                echo "UE4SS source at: $UE4SS_SOURCE_DIR"
              '';
            };
          
          # Create a cross-compiled mod build script (impure - requires network for xwin)
          # Usage: nix run .#build or call the script directly
          mkBuildScript = {
            modDir ? ./.,                                    # Path to mod source (CMake project)
            modName ? "Mod",                                 # Name of the mod
            buildType ? "Game__Shipping__Win64",             # CMake build type
            proxyPath ? "C:\\Windows\\System32\\dwmapi.dll", # Proxy DLL path
          }:
            pkgs.writeShellApplication {
              name = "${modName}-build";
              runtimeInputs = crossCompileBuildInputs;
              text = ''
                # Setup environment
                ${crossCompileEnv}
                export BUILD_TYPE="${buildType}"
                export UE4SS_PROXY_PATH="${proxyPath}"
                
                # We need to wrap the user's mod with a top-level CMakeLists.txt that includes UE4SS.
                # The user's mod source is at ${modDir}, which will be copied/symlinked as a subdirectory.
                
                cat > CMakeLists.txt <<EOF
cmake_minimum_required(VERSION 3.22)
project(UE4SSWrapper)
if(NOT UE4SS_SOURCE_DIR)
    set(UE4SS_SOURCE_DIR "$UE4SS_SOURCE_DIR")
endif()
add_subdirectory("\''${UE4SS_SOURCE_DIR}" RE-UE4SS)
add_subdirectory("src" ${modName})
EOF
                
                # Run setup script (downloads MSVC headers via xwin)
                ${builtins.readFile ./setup_cross_compile.sh}
                
                # Build
                # Determine CPU count (compatible with Linux nproc and macOS sysctl)
                CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)
                cmake --build build-cross -j"''${NIX_BUILD_CORES:-$CORES}" "$@"
                
                echo "Build complete. Output in build-cross/${buildType}/"
              '';
            };
        };
      }
    ) // {
      # Templates for new projects
      templates = {
        default = {
          path = ./templates/default;
          description = "UE4SS C++ Mod with Nix cross-compilation (uses flake-parts)";
        };
      };
    };
}
