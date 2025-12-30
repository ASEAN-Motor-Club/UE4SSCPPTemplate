# UE4SS C++ Mod Template

Cross-compile UE4SS C++ mods for Windows from macOS/Linux using Nix.

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled

## Quick Start

```bash
# 1. Clone with submodules
git clone --recursive https://github.com/UE4SS-RE/UE4SSCPPTemplate.git
cd UE4SSCPPTemplate

# 2. Setup toolchain (downloads MSVC headers, configures CMake)
nix run

# 3. Build
nix run .#build
```

## Available Commands

| Command | Description |
|---------|-------------|
| `nix run` | Setup cross-compilation toolchain |
| `nix run .#setup` | Same as above (explicit alias) |
| `nix run .#build` | Build the project |
| `nix run .#build -- -j8` | Build with custom args (e.g., parallel jobs) |
| `nix develop` | Enter dev shell for manual commands |

## Manual Workflow

If you prefer running commands manually:

```bash
# Enter the development shell
nix develop

# Run setup script
./setup_cross_compile.sh

# Build
cmake --build build-cross
```

## Build Types

Default build type is `Game__Shipping__Win64`. To use a different build type:

```bash
# Set build type before running setup
BUILD_TYPE=Game__Dev__Win64 nix run

# Available build types:
# - Game__Debug__Win64
# - Game__Dev__Win64
# - Game__Shipping__Win64 (default)
# - Game__Test__Win64
```

## Proxy DLL

Default proxy is `dwmapi.dll`. To use a different proxy DLL:

```bash
# Use version.dll instead
UE4SS_PROXY_PATH="C:\Windows\System32\version.dll" nix run
```

## Output

Built mods are located in `build-cross/Game__Shipping__Win64/` after compilation.
