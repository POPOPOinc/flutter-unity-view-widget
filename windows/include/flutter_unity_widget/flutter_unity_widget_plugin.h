#ifndef FLUTTER_PLUGIN_FLUTTER_UNITY_WIDGET_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_FLUTTER_UNITY_WIDGET_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

// For functions called via Dart FFI (internal to the plugin).
#define FFI_PLUGIN_EXPORT __declspec(dllexport)

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void FlutterUnityWidgetPluginRegisterWithRegistrar(
  FlutterDesktopPluginRegistrarRef registrar);

FFI_PLUGIN_EXPORT int32_t FlutterUnityWidgetCreateUnityWindow(
  int32_t left,
  int32_t top,
  int32_t right,
  int32_t bottom);

FFI_PLUGIN_EXPORT void FlutterUnityWidgetDisposeUnityWindow(int32_t id);

FFI_PLUGIN_EXPORT void FlutterUnityWidgetResizeUnityWindow(
  int32_t id,
  int32_t left,
  int32_t top,
  int32_t right,
  int32_t bottom);

FFI_PLUGIN_EXPORT void FlutterUnityWidgetSetOnUnityWindowReady(
  void (*callback)(int32_t id));

FFI_PLUGIN_EXPORT void FlutterUnityWidgetPauseUnityWindow(int32_t id);

FFI_PLUGIN_EXPORT void FlutterUnityWidgetResumeUnityWindow(int32_t id);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_FLUTTER_UNITY_WIDGET_PLUGIN_C_API_H_
