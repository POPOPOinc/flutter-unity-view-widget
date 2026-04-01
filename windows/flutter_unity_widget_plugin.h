#ifndef FLUTTER_PLUGIN_FLUTTER_UNITY_WIDGET_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_UNITY_WIDGET_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_unity_widget {

class FlutterUnityWidgetPlugin : public flutter::Plugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterUnityWidgetPlugin(flutter::PluginRegistrarWindows *registrar);

  virtual ~FlutterUnityWidgetPlugin();

  FlutterUnityWidgetPlugin(const FlutterUnityWidgetPlugin&) = delete;
  FlutterUnityWidgetPlugin& operator=(const FlutterUnityWidgetPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

private:
  flutter::PluginRegistrarWindows *registrar_;
  HWND root_window_;
  std::optional<int32_t> root_window_proc_id_;
};

}  // namespace flutter_unity_widget

#endif  // FLUTTER_PLUGIN_FLUTTER_UNITY_WIDGET_PLUGIN_H_
