#include "include/flutter_unity_widget/flutter_unity_widget_plugin.h"

#include <algorithm>
#include <vector>
#include <flutter/plugin_registrar_windows.h>

#include "flutter_unity_widget_plugin.h"
#include "native_window_container.h"

void FlutterUnityWidgetPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_unity_widget::FlutterUnityWidgetPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

int32_t FlutterUnityWidgetCreateUnityWindow(
  int32_t left,
  int32_t top,
  int32_t right,
  int32_t bottom) {
  return flutter_unity_widget::NativeWindowContainer::Instance()
      ->CreateUnityWindow(left, top, right, bottom);
}

void FlutterUnityWidgetDisposeUnityWindow(int32_t id) {
  flutter_unity_widget::NativeWindowContainer::Instance()->DisposeUnityWindow(id);
}

void FlutterUnityWidgetSetOnUnityWindowReady(
  void (*callback)(int32_t id)) {
  flutter_unity_widget::NativeWindowContainer::Instance()
      ->SetOnUnityWindowReady(callback);
}

void FlutterUnityWidgetResizeUnityWindow(
  int32_t id,
  int32_t left,
  int32_t top,
  int32_t right,
  int32_t bottom) {
  flutter_unity_widget::NativeWindowContainer::Instance()
      ->ResizeUnityWindow(id, left, top, right, bottom);
}

void FlutterUnityWidgetPauseUnityWindow(int32_t id) {
  flutter_unity_widget::NativeWindowContainer::Instance()->PauseUnityWindow(id);
}

void FlutterUnityWidgetResumeUnityWindow(int32_t id) {
  flutter_unity_widget::NativeWindowContainer::Instance()->ResumeUnityWindow(id);
}
