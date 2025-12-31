# UE4SS C++ Mod Template (Nix Cross-Compile)

This is a template for creating C++ mods for UE4SS with a focus on cross-compiling for Windows from macOS/Linux using Nix.

## Quick Start

The easiest way to start a new UE4SS mod is to use the template:

```bash
# Create a new mod project
mkdir MyMod && cd MyMod
nix flake init --template github:ASEAN-Motor-Club/UE4SSCPPTemplate

# Initialize git and build
git init && git add .
nix run
```

This creates a ready-to-use project with:
- `flake.nix` - Uses [flake-parts](https://flake.parts/) for clean structure
- `src/CMakeLists.txt` - Pre-configured CMake build
- `src/main.cpp` - Starter mod with `start_mod()` and `uninstall_mod()` exports

Your compiled DLL will be in `build-cross/Game__Shipping__Win64/bin/`.

---

### Alternative: Manual Setup

If you prefer to set up manually or integrate into an existing project, see [Using as a Library](#using-as-a-library-external-projects).


## Architecture

This project uses a hybrid Nix-based architecture for managing **UE4SS**:
1. **Upstream Source**: Fetched as a Nix flake input from [UE4SS-RE/RE-UE4SS](https://github.com/UE4SS-RE/RE-UE4SS).
2. **Local Overlays**: Custom cross-compilation scripts (`proxy_generator.py`) and `.exports` files reside in the local `proxy_generator/` folder.
3. **Nix Merging**: The project's `flake.nix` automatically applies a minimal CMake patch to upstream and then overlays the local `proxy_generator/` files into the source directory. This resulting "patched source" is exposed via the `UE4SS_SOURCE_DIR` environment variable to the build system.

### Private Submodules
UE4SS depends on some private submodules (e.g., `UEPseudo`). Nix handles this by:
- Using `type = "git"` and `submodules = true` in the flake input.
- **Local Development**: Nix will use your host's Git configuration. If you have an SSH agent or a Personal Access Token (PAT) configured with `insteadOf` rewrites (e.g., `git config --global url."https://x-access-token:YOUR_TOKEN@github.com/".insteadOf "git@github.com:"`), Nix will be able to fetch the private submodules.
- **CI/CD**: The GitHub Actions workflow is pre-configured to handle this using the `UEPSEUDO_PAT` secret.

---

## Overriding UE4SS Source

If you need to update the UE4SS version or use a local fork for testing, you can use standard Nix flake override mechanisms:

### 1. Via CLI (`--override-input`)
If you have a local copy of UE4SS and want to test changes:
```bash
nix run . --override-input ue4ss /path/to/your/local/RE-UE4SS
```

### 2. Via `follows` (Consuming Flake)
If you use this template as a flake input in another project, you can update the UE4SS version in your own `flake.nix`:
```nix
inputs.ue4ss-template.url = "github:ASEAN-Motor-Club/UE4SSCPPTemplate";
inputs.ue4ss-template.inputs.ue4ss.follows = "my-custom-ue4ss-source";
```

### 3. Via `overrideAttrs`
You can override the patched derivation directly in Nix code:
```nix
ue4ss-template.packages.${system}.ue4ss-patched.overrideAttrs (old: {
  src = myCustomSource;
});
```

---

## Available Commands

- `nix run`: Runs `setup_cross_compile.sh` which sets up the MSVC toolchain, configures CMake, and tells you how to build.
- `nix run .#build`: Performs a full build of the project.
- `nix run .#setup`: Native setup (for future use).

---

## Documentation

### Build Types
You can specify the build type by setting the `BUILD_TYPE` environment variable before running the setup script.
Defaults to `Game__Shipping__Win64`.

### Proxy DLL Path
You can specify the path to an alternative proxy DLL (like `version.dll`) by setting the `UE4SS_PROXY_PATH` environment variable.
Defaults to `C:\Windows\System32\dwmapi.dll`.

---

## Using as a Library (External Projects)
See the [Quick Start](#quick-start) section for a complete template.

> [!IMPORTANT]
> Builds are **impure** because `xwin` downloads MSVC headers at build time. You cannot use `nix build` for a fully reproducible package. Instead, use `nix run` or enter the dev shell.

### Available Library Functions

| Function | Description |
|----------|-------------|
| `lib.mkDevShell { extraBuildInputs ? [] }` | Creates a dev shell with all cross-compile tools |
| `lib.mkBuildScript { modDir, modName, ... }` | Creates an impure build script (run with `nix run`) |
| `lib.patchedUE4SS` | The patched UE4SS source derivation |
| `lib.crossCompileBuildInputs` | List of build inputs for cross-compilation |
| `lib.crossCompileEnv` | Environment setup shell script |
