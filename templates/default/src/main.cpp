#include <Mod/CppUserModBase.hpp>

class MyMod : public RC::CppUserModBase {
public:
  MyMod() : CppUserModBase() {
    ModName = STR("MyMod");
    ModVersion = STR("1.0.0");
    ModDescription = STR("A UE4SS C++ Mod created from template");
    ModAuthors = STR("Your Name");
  }

  ~MyMod() override = default;

  auto on_update() -> void override {
    // Called every frame
  }

  auto on_unreal_init() -> void override {
    // Called when Unreal Engine is ready
  }
};

#define MY_AWESOME_MOD_API __declspec(dllexport)
extern "C" {
MY_AWESOME_MOD_API RC::CppUserModBase *start_mod() { return new MyMod(); }

MY_AWESOME_MOD_API void uninstall_mod(RC::CppUserModBase *mod) { delete mod; }
}
