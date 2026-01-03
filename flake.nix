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
          name = "configure-cross-compile";
          runtimeInputs = crossCompileBuildInputs;
          text = ''
            # Setup environment variables
            ${crossCompileEnv}
            
            # Source the original script content
            ${builtins.readFile ./setup_cross_compile.sh}
          '';
        };

        # Alias for explicit naming
        packages.configure = self.packages.${system}.default;

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

        apps.configure = self.apps.${system}.default;

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
          mkConfigureScript = {
            modName ? "Mod",                                 # Name of the mod
            buildType ? "Game__Shipping__Win64",             # CMake build type
            proxyPath ? "C:\\Windows\\System32\\dwmapi.dll", # Proxy DLL path
          }:
            pkgs.writeShellApplication {
              name = "${modName}-configure";
              runtimeInputs = crossCompileBuildInputs;
              text = ''
                # Setup environment
                ${crossCompileEnv}
                export BUILD_TYPE="${buildType}"
                export UE4SS_PROXY_PATH="${proxyPath}"
                
                # Create CMakeLists.txt wrapper
                cat > CMakeLists.txt <<EOF
cmake_minimum_required(VERSION 3.22)
project(UE4SSWrapper)
if(NOT UE4SS_SOURCE_DIR)
    set(UE4SS_SOURCE_DIR "$UE4SS_SOURCE_DIR")
endif()
add_subdirectory("\''${UE4SS_SOURCE_DIR}" RE-UE4SS)
add_subdirectory("src" ${modName})
EOF
                
                # Run setup script (downloads MSVC headers via xwin and runs cmake -B)
                ${builtins.readFile ./setup_cross_compile.sh}
              '';
            };

          mkBuildScript = {
            modName ? "Mod",                                 # Name of the mod
            buildType ? "Game__Shipping__Win64",             # Only used for logging here
          }:
            pkgs.writeShellApplication {
              name = "${modName}-build";
              runtimeInputs = crossCompileBuildInputs;
              text = ''
                # Setup environment
                ${crossCompileEnv}
                
                if [ ! -d "build-cross" ]; then
                  echo "Error: build-cross directory not found. Please run 'nix run .#configure' first."
                  exit 1
                fi
                
                # Build
                # Determine CPU count (compatible with Linux nproc and macOS sysctl)
                CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)
                cmake --build build-cross -j"''${NIX_BUILD_CORES:-$CORES}" "$@"
                
                echo "Build complete. Output in build-cross/${buildType}/"
              '';
            };

          # Create a packaging script that assembles a deployable UE4SS mod package
          # This creates the standard UE4SS directory structure ready to copy to game dir
          mkPackageScript = {
            modName ? "Mod",                                 # Name of the mod
            buildType ? "Game__Shipping__Win64",             # CMake build type
            luaScriptsDir ? null,                            # Path to Lua scripts (null = no Lua scripts)
            sharedLuaDir ? null,                             # Path to shared Lua libs (e.g. ./shared) - copied to ue4ss/Mods/shared/
            includeSettings ? true,                          # Include UE4SS-settings.ini
            enabledTxtPath ? null,                           # Path to enabled.txt (null = create default)
          }:
            pkgs.writeShellApplication {
              name = "${modName}-package";
              runtimeInputs = with pkgs; [ coreutils zip gnused ];
              text = ''
                set -e
                
                MOD_NAME="${modName}"
                BUILD_TYPE="${buildType}"
                PACKAGE_DIR="package"
                LUA_SCRIPTS_DIR="${if luaScriptsDir != null then luaScriptsDir else ""}"
                SHARED_LUA_DIR="${if sharedLuaDir != null then sharedLuaDir else ""}"
                INCLUDE_SETTINGS="${if includeSettings then "true" else "false"}"
                ENABLED_TXT_PATH="${if enabledTxtPath != null then enabledTxtPath else ""}"
                UE4SS_SETTINGS_SRC="${patchedUE4SS}/assets/UE4SS-settings.ini"
                
                echo "=========================================="
                echo "Packaging $MOD_NAME for distribution"
                echo "=========================================="
                
                # Verify build exists
                if [ ! -d "build-cross" ]; then
                  echo "Error: build-cross directory not found. Please run 'nix run .#build' first."
                  exit 1
                fi
                
                # Find proxy DLL
                PROXY_DLL=""
                for proxy in "version.dll" "dwmapi.dll"; do
                  if [ -f "build-cross/$BUILD_TYPE/bin/$proxy" ]; then
                    PROXY_DLL="$proxy"
                    break
                  fi
                done
                
                if [ -z "$PROXY_DLL" ]; then
                  echo "Error: No proxy DLL (version.dll or dwmapi.dll) found in build-cross/$BUILD_TYPE/bin/"
                  exit 1
                fi
                
                # Verify required files exist
                if [ ! -f "build-cross/$BUILD_TYPE/bin/UE4SS.dll" ]; then
                  echo "Error: UE4SS.dll not found in build-cross/$BUILD_TYPE/bin/"
                  exit 1
                fi
                
                if [ ! -f "build-cross/$MOD_NAME/$MOD_NAME.dll" ]; then
                  echo "Error: $MOD_NAME.dll not found in build-cross/$MOD_NAME/"
                  exit 1
                fi
                
                echo "Found proxy DLL: $PROXY_DLL"
                echo "Creating package structure..."
                
                # Clean and create package directory
                rm -rf "$PACKAGE_DIR"
                mkdir -p "$PACKAGE_DIR/ue4ss/Mods/$MOD_NAME/dlls"
                
                # Copy proxy DLL to root (where game .exe is)
                cp "build-cross/$BUILD_TYPE/bin/$PROXY_DLL" "$PACKAGE_DIR/"
                echo "✓ Copied $PROXY_DLL"
                
                # Copy UE4SS.dll to ue4ss/
                cp "build-cross/$BUILD_TYPE/bin/UE4SS.dll" "$PACKAGE_DIR/ue4ss/"
                echo "✓ Copied UE4SS.dll"
                
                # Copy mod DLL (renamed to main.dll per UE4SS convention)
                cp "build-cross/$MOD_NAME/$MOD_NAME.dll" "$PACKAGE_DIR/ue4ss/Mods/$MOD_NAME/dlls/main.dll"
                echo "✓ Copied $MOD_NAME.dll -> dlls/main.dll"
                
                # Copy Lua scripts if specified
                if [ -n "$LUA_SCRIPTS_DIR" ] && [ -d "$LUA_SCRIPTS_DIR" ]; then
                  mkdir -p "$PACKAGE_DIR/ue4ss/Mods/$MOD_NAME/Scripts"
                  cp -r "$LUA_SCRIPTS_DIR"/* "$PACKAGE_DIR/ue4ss/Mods/$MOD_NAME/Scripts/"
                  SCRIPT_COUNT=$(find "$PACKAGE_DIR/ue4ss/Mods/$MOD_NAME/Scripts" -name "*.lua" | wc -l)
                  echo "✓ Copied $SCRIPT_COUNT Lua scripts"
                fi
                
                # Copy or create enabled.txt
                if [ -n "$ENABLED_TXT_PATH" ] && [ -f "$ENABLED_TXT_PATH" ]; then
                  cp "$ENABLED_TXT_PATH" "$PACKAGE_DIR/ue4ss/Mods/$MOD_NAME/enabled.txt"
                else
                  touch "$PACKAGE_DIR/ue4ss/Mods/$MOD_NAME/enabled.txt"
                fi
                echo "✓ Created enabled.txt"
                
                # Copy UE4SS settings if requested
                if [ "$INCLUDE_SETTINGS" = "true" ]; then
                  if [ -f "$UE4SS_SETTINGS_SRC" ]; then
                    cp --no-preserve=mode,ownership "$UE4SS_SETTINGS_SRC" "$PACKAGE_DIR/ue4ss/UE4SS-settings.ini"
                    # Apply production patches (disable console and debug GUI)
                    sed -i 's/^ConsoleEnabled\s*=.*/ConsoleEnabled = 0/' "$PACKAGE_DIR/ue4ss/UE4SS-settings.ini"
                    sed -i 's/^GuiConsoleEnabled\s*=.*/GuiConsoleEnabled = 0/' "$PACKAGE_DIR/ue4ss/UE4SS-settings.ini"
                    sed -i 's/^GuiConsoleVisible\s*=.*/GuiConsoleVisible = 0/' "$PACKAGE_DIR/ue4ss/UE4SS-settings.ini"
                    sed -i 's/^EnableHotReloadSystem\s*=.*/EnableHotReloadSystem = 0/' "$PACKAGE_DIR/ue4ss/UE4SS-settings.ini"
                    echo "✓ Copied and patched UE4SS-settings.ini from upstream"
                  else
                    echo "⚠ Warning: Upstream UE4SS-settings.ini not found at $UE4SS_SETTINGS_SRC"
                  fi
                fi
                
                # Copy shared folder (contains UEHelpers and other Lua utilities)
                UE4SS_SHARED_SRC="${patchedUE4SS}/assets/Mods/shared"
                if [ -d "$UE4SS_SHARED_SRC" ]; then
                  cp --no-preserve=mode,ownership -r "$UE4SS_SHARED_SRC" "$PACKAGE_DIR/ue4ss/Mods/"
                  echo "✓ Copied shared folder (UEHelpers, Types.lua, etc.)"
                else
                  echo "⚠ Warning: shared folder not found at $UE4SS_SHARED_SRC"
                fi
                
                # Copy project-local shared Lua libraries (e.g. MTHelpers)
                if [ -n "$SHARED_LUA_DIR" ] && [ -d "$SHARED_LUA_DIR" ]; then
                  # Copy contents into the shared folder (next to UEHelpers)
                  cp -r "$SHARED_LUA_DIR"/* "$PACKAGE_DIR/ue4ss/Mods/shared/"
                  echo "✓ Copied project shared Lua libraries from $SHARED_LUA_DIR"
                fi
                
                # Create mods.txt
                echo "$MOD_NAME : 1" > "$PACKAGE_DIR/ue4ss/Mods/mods.txt"
                echo "✓ Created mods.txt"
                
                # Create mods.json
                cat > "$PACKAGE_DIR/ue4ss/Mods/mods.json" << EOF
[
    {
        "mod_name": "$MOD_NAME",
        "mod_enabled": true
    }
]
EOF
                echo "✓ Created mods.json"
                
                echo ""
                echo "Package structure:"
                find "$PACKAGE_DIR" -type f | sort | sed 's/^/  /'
                
                # Create zip
                ZIP_NAME="$MOD_NAME-package.zip"
                rm -f "$ZIP_NAME"
                (cd "$PACKAGE_DIR" && zip -r "../$ZIP_NAME" .)
                
                echo ""
                echo "=========================================="
                echo "✓ Package created: $ZIP_NAME"
                echo "=========================================="
                echo ""
                echo "To deploy:"
                echo "  1. Extract $ZIP_NAME to your game's executable directory"
                echo "  2. The proxy DLL ($PROXY_DLL) should be next to the game .exe"
                echo "  3. The ue4ss/ folder should be in the same directory"
                echo ""
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
