#ifndef NATIVE_WINDOW_CONTAINER_H_
#define NATIVE_WINDOW_CONTAINER_H_

#include <Windows.h>

#include <cstdint>
#include <optional>
#include <vector>

namespace flutter_unity_widget {

  typedef void (*UnityWindowReadyCallback)(int32_t id);

  enum WinPlayerStates
  {
    kPlayerStateGraphicsInitialized = 1,
    kPlayerStateUnitySplashDone = 1 << 1,
  };

  /// <summary>
  /// Unity インスタンスごとの情報をまとめた構造体
  /// </summary>
  struct UnityInstanceHandle {
    int32_t id = 0;                    // Dart に渡すインクリメント整数ID
    HWND container_window = nullptr;   // 作成したコンテナウインドウ (target_window)
    std::optional<HWND> unity_window;  // Unity内部ウインドウ (UnityWndClass)
    HANDLE exit_event = nullptr;       // UnityMainスレッド終了イベント

    /// Unity描画ループを再開させる (WM_ACTIVATE/WA_ACTIVE)
    void Activate() {
      if (unity_window) {
        ::SendMessage(*unity_window, WM_ACTIVATE,
                      MAKEWPARAM(WA_ACTIVE, 0), 0);
      }
    }

    /// Unity描画ループを一時停止させる (WM_ACTIVATE/WA_INACTIVE)
    void Deactivate() {
      if (unity_window) {
        ::SendMessage(*unity_window, WM_ACTIVATE,
                      MAKEWPARAM(WA_INACTIVE, WA_INACTIVE), 0);
      }
    }
  };

  class NativeWindowContainer {
  public:
    static NativeWindowContainer *Instance();
    void CreateContainerWindow();
    void PositionAndShowContainerWindow(HWND flutterWindow);
    void DisposeWindow();

    int32_t CreateUnityWindow(int left, int top, int right, int bottom);

    void DisposeUnityWindow(int32_t id);
    void ResizeUnityWindow(int32_t id, int left, int top, int right, int bottom);
    void PauseUnityWindow(int32_t id);
    void ResumeUnityWindow(int32_t id);
    void SetOnUnityWindowReady(UnityWindowReadyCallback callback);

    static LRESULT CALLBACK ContainerWindowProc(HWND const window, UINT const message, WPARAM const wparam, LPARAM const lparam) noexcept;
    std::optional<LRESULT> FlutterMainWindowProcCallback(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

  private:
    static constexpr auto kContainerWindowClassName = L"FlutterUnityWidgetContainer";
    static constexpr auto kWindowName = L"FlutterUnityWidgetContainer";
    static constexpr auto kUnityContainerWindowClassName = L"FlutterUnityWidgetUnityContainer";
    static constexpr auto kUnityInternalWindowClassName = L"UnityWndClass";

    bool LoadUnityPlayerDll();
    void StartUnityThread(HINSTANCE h_instance, HWND target_window, int32_t id, HANDLE exit_event);
    void PollUnityWindows();
    void OnRestoreTimer();
    static void CALLBACK RestoreTimerProc(HWND hwnd, UINT msg, UINT_PTR id, DWORD time);
    void BringFlutterToFront();
    std::vector<UnityInstanceHandle>::iterator FindHandle(int32_t id);

    HWND container_window_ = nullptr;
    HWND flutter_main_window_ = nullptr;
    HMODULE unity_module_ = nullptr;
    std::vector<UnityInstanceHandle> unity_handles_;
    int32_t next_id_ = 1;

    WPARAM last_wm_size_wparam_ = 0;
    bool was_window_hidden_due_to_minimize_ = false;
    bool is_in_sizemove_ = false;
    UnityWindowReadyCallback on_unity_window_ready_ = nullptr;
  };
}

#endif