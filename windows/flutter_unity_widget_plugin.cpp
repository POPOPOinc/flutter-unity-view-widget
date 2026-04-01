#include "flutter_unity_widget_plugin.h"
#include "native_window_container.h"
#include "window_composition_utility.h"

#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <shlwapi.h>  // PathRemoveFileSpecW

#include <cstdio>
#include <memory>
#include <sstream>

#include "log_util.h"

namespace flutter_unity_widget {

void FlutterUnityWidgetPlugin::RegisterWithRegistrar (
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<FlutterUnityWidgetPlugin>(registrar);

  auto channel =
    std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "plugin.xraph.com/unity_view",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterUnityWidgetPlugin::FlutterUnityWidgetPlugin(
  flutter::PluginRegistrarWindows *registrar
  ) : registrar_(registrar) {

  // Add unityLibrary to DLL search path so that UnityPlayer.dll etc. can be loaded.
  {
    wchar_t exe_path[MAX_PATH];
    GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
    PathRemoveFileSpecW(exe_path);

    wchar_t unity_path[MAX_PATH];
    wcscpy_s(unity_path, MAX_PATH, exe_path);
    wcscat_s(unity_path, MAX_PATH, L"\\unityLibrary");

    bool ok = (AddDllDirectory(unity_path) != nullptr);

    DebugLog("[flutter_unity_widget] AddDllDirectory: %ls -> %s",
        unity_path, ok ? "OK" : "FAILED");
  }

  auto window = registrar_->GetView()->GetNativeWindow();
  root_window_ = ::GetAncestor(window, GA_ROOT);

  NativeWindowContainer::Instance()->CreateContainerWindow();

  root_window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
    [=](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
      return NativeWindowContainer::Instance()->FlutterMainWindowProcCallback(hwnd, message, wparam, lparam);
    });

  NativeWindowContainer::Instance()->PositionAndShowContainerWindow(root_window_);
}

FlutterUnityWidgetPlugin::~FlutterUnityWidgetPlugin() {
  if (root_window_proc_id_) {
    registrar_->UnregisterTopLevelWindowProcDelegate(root_window_proc_id_.value());
  }
}

void FlutterUnityWidgetPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
}

}  // namespace flutter_unity_widget
