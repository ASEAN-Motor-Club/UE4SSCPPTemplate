# MyMod - UE4SS C++ Mod

This project was created using the UE4SS C++ Mod template.

## Quick Start

1. **Enter the development shell**:
   ```bash
   nix develop
   ```

2. **Build the mod**:
   ```bash
   nix run
   ```

3. **Find your output** in `build-cross/Game__Shipping__Win64/bin/`

## Project Structure

- `src/` - Your mod source code
  - `main.cpp` - Entry point with `start_mod()` and `uninstall_mod()` exports
  - `CMakeLists.txt` - CMake build configuration
- `flake.nix` - Nix flake configuration

## Customization

### Rename Your Mod

1. Update `modName` in `flake.nix`
2. Update `project(MyMod)` in `src/CMakeLists.txt`
3. Update `add_library(MyMod ...)` in `src/CMakeLists.txt`
4. Update class name and metadata in `src/main.cpp`

### Build Types

Set `BUILD_TYPE` environment variable before building:
- `Game__Shipping__Win64` (default)
- `Game__Dev__Win64`

### Proxy DLL

Set `UE4SS_PROXY_PATH` to use a different proxy DLL:
- Default: `C:\Windows\System32\dwmapi.dll`
- Alternative: `C:\Windows\System32\version.dll`

## Resources

- [UE4SS Documentation](https://docs.ue4ss.com/)
- [Template Repository](https://github.com/ASEAN-Motor-Club/UE4SSCPPTemplate)
