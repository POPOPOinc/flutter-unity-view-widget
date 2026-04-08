#include <ShObjIdl.h>
#include <algorithm>
#include <thread>
#include <string>
#include "native_window_container.h"
#include "window_composition_utility.h"
#include "log_util.h"

typedef int (WINAPI *UnityMainFunc)(HINSTANCE, HINSTANCE, LPWSTR, int);

namespace flutter_unity_widget {
  static constexpr UINT_PTR kContainerWindowRestoreTimerId = 999999999;
  static constexpr UINT_PTR kUnityPollTimerId = 2;
  static constexpr UINT kNativeViewPositionAndShowDelay = 200;
  static constexpr DWORD kUnityPollIntervalMs = 30;

  NativeWindowContainer* NativeWindowContainer::Instance() {
    static NativeWindowContainer instance;
    return &instance;
  }

  void NativeWindowContainer::CreateContainerWindow() {
      auto window_class = WNDCLASSEX{};
      window_class.cbSize = sizeof(window_class);
      window_class.style = CS_HREDRAW | CS_VREDRAW;
      window_class.lpfnWndProc = ContainerWindowProc;
      window_class.hInstance = 0;
      window_class.lpszClassName = kContainerWindowClassName;
      window_class.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
      window_class.hbrBackground = ::CreateSolidBrush(0);

      ::RegisterClassExW(&window_class);
      container_window_ =
              ::CreateWindowExW(WS_EX_NOACTIVATE, kContainerWindowClassName, kWindowName, WS_OVERLAPPEDWINDOW,
                             CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
                             nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
      auto disable_window_transitions = TRUE;
      DwmSetWindowAttribute(container_window_, DWMWA_TRANSITIONS_FORCEDISABLED,
                            &disable_window_transitions,
                            sizeof(disable_window_transitions));

    ITaskbarList3* taskbar = nullptr;
    ::CoCreateInstance(CLSID_TaskbarList, 0, CLSCTX_INPROC_SERVER,
                       IID_PPV_ARGS(&taskbar));
    taskbar->DeleteTab(container_window_);
    taskbar->Release();
  }

  void NativeWindowContainer::PositionAndShowContainerWindow(HWND flutter_window) {
    flutter_main_window_ = flutter_window;

    ::SetWindowLongPtr(container_window_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(flutter_window));

    RECT window_rect;
    ::GetWindowRect(flutter_window, &window_rect);
    ::SetWindowPos(container_window_, flutter_window,
                   window_rect.left, window_rect.top,
                   window_rect.right - window_rect.left,
                   window_rect.bottom - window_rect.top,
                   SWP_NOACTIVATE);

    ::ShowWindow(container_window_, SW_SHOWNOACTIVATE);
    ::UpdateWindow(container_window_);
    ::SetFocus(flutter_window);
  }

  void NativeWindowContainer::DisposeWindow() {
    if (container_window_) {
      ::DestroyWindow(container_window_);
      container_window_ = nullptr;
    }
    flutter_main_window_ = nullptr;
  }

  void NativeWindowContainer::DisposeUnityWindow(int32_t id) {
    DebugLog("[flutter_unity_widget] DisposeUnityWindow: id=%d", id);
    auto it = FindHandle(id);
    if (it == unity_handles_.end()) return;

    HWND container = it->container_window;

    if (it->unity_window) {
      ::SendMessage(*it->unity_window, WM_CLOSE, 0, 0);
    }

    if (it->exit_event) {
      DebugLog("[flutter_unity_widget] DisposeUnityWindow: waiting for UnityMain thread...");
      DWORD result = ::WaitForSingleObject(it->exit_event, 5000);
      if (result == WAIT_OBJECT_0) {
        DebugLog("[flutter_unity_widget] DisposeUnityWindow: UnityMain thread finished");
      } else {
        DebugLog("[flutter_unity_widget] DisposeUnityWindow: wait timed out (result=%lu)", result);
      }
      ::CloseHandle(it->exit_event);
    }
    unity_handles_.erase(it);

    DebugLog("[flutter_unity_widget] DisposeUnityWindow: DestroyWindow hwnd=%p", container);
    ::DestroyWindow(container);
    DebugLog("[flutter_unity_widget] DisposeUnityWindow: done");
  }

  int32_t NativeWindowContainer::CreateUnityWindow(int left, int top, int right, int bottom) {
    if (!container_window_) {
      DebugLog("[flutter_unity_widget] CreateUnityWindow: container_window_ is null");
      return 0;
    }

    if (!LoadUnityPlayerDll()) {
      return 0;
    }

    auto h_instance = ::GetModuleHandle(nullptr);

    static bool child_class_registered = false;
    if (!child_class_registered) {
      auto wc = WNDCLASSEX{};
      wc.cbSize = sizeof(wc);
      wc.lpfnWndProc = ::DefWindowProc;
      wc.hInstance = h_instance;
      wc.lpszClassName = kUnityContainerWindowClassName;
      wc.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
      wc.hbrBackground = static_cast<HBRUSH>(::GetStockObject(BLACK_BRUSH));
      ::RegisterClassExW(&wc);
      child_class_registered = true;
    }

    int width = right - left;
    int height = bottom - top;

    HWND window = ::CreateWindowExW(
      WS_EX_NOACTIVATE,
      kUnityContainerWindowClassName,
      L"UnityContainer",
      WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN,
      left, top, width, height,
      container_window_,
      nullptr,
      h_instance,
      nullptr);

    int32_t id = next_id_++;
    HANDLE exit_event = ::CreateEvent(nullptr, TRUE, FALSE, nullptr);
    unity_handles_.push_back({id, window, std::nullopt, exit_event});

    StartUnityThread(h_instance, window, id, exit_event);
    return id;
  }

  void NativeWindowContainer::ResizeUnityWindow(int32_t id, int left, int top, int right, int bottom) {
    auto it = FindHandle(id);

    int width = right - left;
    int height = bottom - top;
    ::MoveWindow(it->container_window, left, top, width, height, TRUE);

    RECT rc;
    ::GetClientRect(it->container_window, &rc);
    ::MoveWindow(*it->unity_window, 0, 0, rc.right, rc.bottom, TRUE);
  }

  void NativeWindowContainer::PauseUnityWindow(int32_t id) {
    auto it = FindHandle(id);
    if (it == unity_handles_.end()) return;
    DebugLog("[flutter_unity_widget] PauseUnityWindow id=%d", id);
    it->Deactivate();
  }

  void NativeWindowContainer::ResumeUnityWindow(int32_t id) {
    auto it = FindHandle(id);
    if (it == unity_handles_.end()) return;
    DebugLog("[flutter_unity_widget] ResumeUnityWindow id=%d", id);
    it->Activate();
    BringFlutterToFront();
  }

  void NativeWindowContainer::SetOnUnityWindowReady(UnityWindowReadyCallback callback) {
    on_unity_window_ready_ = callback;
  }

  std::vector<UnityInstanceHandle>::iterator NativeWindowContainer::FindHandle(int32_t id) {
    return std::find_if(unity_handles_.begin(), unity_handles_.end(),
        [id](const UnityInstanceHandle& h) { return h.id == id; });
  }

  bool NativeWindowContainer::LoadUnityPlayerDll() {
    if (unity_module_) {
      return true;
    }
    unity_module_ = ::LoadLibraryExW(
        L"UnityPlayer.dll", nullptr, LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    if (!unity_module_) {
      DebugLog("[flutter_unity_widget] LoadLibraryExW(UnityPlayer.dll) failed: %lu",
          ::GetLastError());
      return false;
    }
    DebugLog("[flutter_unity_widget] UnityPlayer.dll loaded");
    return true;
  }

  void NativeWindowContainer::StartUnityThread(HINSTANCE h_instance, HWND target_window, int32_t id, HANDLE exit_event)
  {
    // UnityPlayer.dll のディレクトリから *_Data フォルダを探す
    std::wstring data_folder;
    {
      wchar_t dll_path[MAX_PATH];
      if (::GetModuleFileNameW(unity_module_, dll_path, MAX_PATH)) {
        ::PathRemoveFileSpecW(dll_path);

        std::wstring search_pattern = std::wstring(dll_path) + L"\\*_Data";
        WIN32_FIND_DATAW find_data;
        HANDLE hFind = ::FindFirstFileW(search_pattern.c_str(), &find_data);
        if (hFind != INVALID_HANDLE_VALUE) {
          do {
            if (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
              data_folder = std::wstring(dll_path) + L"\\" + find_data.cFileName;
              break;
            }
          } while (::FindNextFileW(hFind, &find_data));
          ::FindClose(hFind);
        }
      }
      DebugLog("[flutter_unity_widget] Data folder: %ls",
          data_folder.empty() ? L"(not found)" : data_folder.c_str());
    }

    std::thread([this, h_instance, target_window, exit_event, data_folder]()
    {
      auto unityMain = (UnityMainFunc)GetProcAddress(unity_module_, "UnityMain");
      if (!unityMain) {
        ::SetEvent(exit_event);
        return;
      }
      std::wstring cmdLine =
        std::wstring(L"-hideWindow ") +
        L"-parentHWND " + std::to_wstring((uintptr_t)target_window);
      DebugLog("[flutter_unity_widget] UnityMain starting with cmdLine: %ls",
          cmdLine.c_str());
      unityMain(h_instance,
                reinterpret_cast<HINSTANCE>(data_folder.empty() ? nullptr : data_folder.c_str()),
                const_cast<LPWSTR>(cmdLine.c_str()),
                SW_SHOWNOACTIVATE);
      ::SetEvent(exit_event);
    }).detach();

    ::SetTimer(container_window_, kUnityPollTimerId, kUnityPollIntervalMs, nullptr);
    DebugLog("[flutter_unity_widget] Unity poll timer started for id=%d target=%p", id, target_window);
  }

  void NativeWindowContainer::PollUnityWindows() {
    bool has_pending = false;

    for (auto it = unity_handles_.begin(); it != unity_handles_.end(); ) {
      if (it->unity_window.has_value()) {
        ++it;
        continue;
      }

      if (::WaitForSingleObject(it->exit_event, 0) == WAIT_OBJECT_0) {
        DebugLog("[flutter_unity_widget] Unity window not found, destroying container %p",
            it->container_window);
        HWND container = it->container_window;
        ::CloseHandle(it->exit_event);
        it = unity_handles_.erase(it);
        ::DestroyWindow(container);
        continue;
      }

      // container_window の子ウィンドウから Unity の内部ウィンドウを検索する。
      // 検索条件:
      //   1. ウィンドウクラス名が "UnityWndClass" であること
      //   2. GWLP_USERDATA の最下位ビット (kPlayerStateGraphicsInitialized) が
      //      セットされていること (= Unity のグラフィックス初期化が完了済み)
      HWND found_hwnd = nullptr;
      struct FindData { HWND result; const wchar_t* class_name; DWORD pid; };
      FindData find_data = { nullptr, kUnityInternalWindowClassName, ::GetCurrentProcessId() };

      ::EnumChildWindows(it->container_window, [](HWND child, LPARAM lParam) -> BOOL {
        auto* data = reinterpret_cast<FindData*>(lParam);
        wchar_t cls[256] = {};
        ::GetClassNameW(child, cls, 256);
        if (wcscmp(cls, data->class_name) == 0) {
          auto userData = ::GetWindowLongPtr(child, GWLP_USERDATA);
          if ((userData & kPlayerStateGraphicsInitialized) != 0) {
            data->result = child;
            return FALSE;
          }
        }
        return TRUE;
      }, reinterpret_cast<LPARAM>(&find_data));
      found_hwnd = find_data.result;

      if (found_hwnd) {
        it->unity_window = found_hwnd;

        auto exstyle = ::GetWindowLongPtr(found_hwnd, GWL_EXSTYLE);
        exstyle &= ~WS_EX_NOACTIVATE;
        ::SetWindowLongPtr(found_hwnd, GWL_EXSTYLE, exstyle);

        auto style = ::GetWindowLongPtr(found_hwnd, GWL_STYLE);
        style |= WS_VISIBLE;
        ::SetWindowLongPtr(found_hwnd, GWL_STYLE, style);

        DebugLog("[flutter_unity_widget] Unity window %p reparented to %p", found_hwnd, it->container_window);
        ::SetParent(found_hwnd, it->container_window);
        if (flutter_main_window_) {
          ::SetFocus(flutter_main_window_);
          ::UpdateWindow(flutter_main_window_);
          ::SetForegroundWindow(flutter_main_window_);
          ::ShowWindow(found_hwnd, SW_SHOW);
        }

        if (on_unity_window_ready_) {
          on_unity_window_ready_(it->id);
        }

        ++it;
        continue;
      }

      has_pending = true;
      ++it;
    }

    if (!has_pending) {
      ::KillTimer(container_window_, kUnityPollTimerId);
      DebugLog("[flutter_unity_widget] Unity poll timer stopped (no pending)");
    }
  }

  void CALLBACK NativeWindowContainer::RestoreTimerProc(
      HWND hwnd, UINT msg, UINT_PTR id, DWORD time) {
    DebugLog("[DEBUG] RestoreTimerProc: fired! hwnd=%p id=%llu", hwnd, (unsigned long long)id);
    ::KillTimer(hwnd, id);
    NativeWindowContainer::Instance()->OnRestoreTimer();
  }

  void NativeWindowContainer::OnRestoreTimer() {
    HWND hwnd = flutter_main_window_;
    if (!hwnd) {
      return;
    }

    if (::IsIconic(hwnd)) {
      return;
    }

    SetWindowComposition(hwnd, ACCENT_INVALID_STATE, 0);

    RECT window_rect;
    ::GetWindowRect(hwnd, &window_rect);
    ::SetWindowPos(container_window_, hwnd,
                   window_rect.left,
                   window_rect.top,
                   window_rect.right - window_rect.left,
                   window_rect.bottom - window_rect.top,
                   SWP_NOACTIVATE | SWP_SHOWWINDOW);

    if (!::IsWindowVisible(container_window_)) {
      ::ShowWindow(container_window_, SW_SHOWNOACTIVATE);
    }

    for (auto& handle : unity_handles_) {
      handle.Activate();
    }
    BringFlutterToFront();
  }

  void NativeWindowContainer::BringFlutterToFront() {
    if (!flutter_main_window_) return;
    ::SetForegroundWindow(flutter_main_window_);
    ::SetFocus(flutter_main_window_);
  }

  LRESULT CALLBACK NativeWindowContainer::ContainerWindowProc(
    HWND const window,
    UINT const message,
    WPARAM const wparam,
    LPARAM const lparam) noexcept {
    switch (message) {
      case WM_DESTROY: {
        ::PostQuitMessage(0);
        return 0;
      }
      case WM_MOUSEMOVE: {
        TRACKMOUSEEVENT event;
        event.cbSize = sizeof(event);
        event.hwndTrack = window;
        event.dwFlags = TME_HOVER;
        event.dwHoverTime = 200;
        auto user_data = ::GetWindowLongPtr(window, GWLP_USERDATA);
        if (user_data) {
          ::SetForegroundWindow(reinterpret_cast<HWND>(user_data));
        }
        break;
      }
      case WM_MOUSEACTIVATE: {
        return MA_NOACTIVATE;
      }
      case WM_ERASEBKGND: {
        return 1;
      }
      case WM_SIZE:
      case WM_MOVE:
      case WM_MOVING:
      case WM_ACTIVATE:
      case WM_WINDOWPOSCHANGED: {
        if (!NativeWindowContainer::Instance()->is_in_sizemove_) {
          auto user_data = ::GetWindowLongPtr(window, GWLP_USERDATA);
          if (user_data) {
            ::SetForegroundWindow(reinterpret_cast<HWND>(user_data));
          }
        }
        break;
      }
      case WM_TIMER: {
        if (wparam == kUnityPollTimerId) {
          NativeWindowContainer::Instance()->PollUnityWindows();
        }
        break;
      }
      default:
        break;
      }
      return ::DefWindowProc(window, message, wparam, lparam);
  }

  std::optional<LRESULT> NativeWindowContainer::FlutterMainWindowProcCallback(
    HWND hwnd,
    UINT message,
    WPARAM wparam,
    LPARAM lparam) {
   switch (message) {
     case WM_ACTIVATE: {
       if (LOWORD(wparam) == WA_INACTIVE) {
         break;
       }

       SetWindowComposition(hwnd, ACCENT_INVALID_STATE, 0);

       RECT window_rect;
       ::GetWindowRect(hwnd, &window_rect);

       ::SetWindowPos(container_window_, hwnd,
                      window_rect.left,
                      window_rect.top,
                      window_rect.right - window_rect.left,
                      window_rect.bottom - window_rect.top,
                      SWP_NOACTIVATE);
       break;
     }
     case WM_SIZE: {
       if (wparam != SIZE_RESTORED ||
           last_wm_size_wparam_ == SIZE_MINIMIZED ||
           last_wm_size_wparam_ == SIZE_MAXIMIZED ||
           was_window_hidden_due_to_minimize_) {
         was_window_hidden_due_to_minimize_ = false;
         SetWindowComposition(hwnd, ACCENT_DISABLED, 0);
         ::ShowWindow(container_window_, SW_HIDE);
         ::KillTimer(flutter_main_window_, kContainerWindowRestoreTimerId);
         ::SetTimer(flutter_main_window_, kContainerWindowRestoreTimerId, kNativeViewPositionAndShowDelay, RestoreTimerProc);
       }
       last_wm_size_wparam_ = wparam;
       break;
     }
     case WM_TIMER: {
       if (wparam == kContainerWindowRestoreTimerId) {
         ::KillTimer(flutter_main_window_, kContainerWindowRestoreTimerId);

         if (::IsIconic(hwnd)) {
           break;
         }

         SetWindowComposition(hwnd, ACCENT_INVALID_STATE, 0);

         RECT window_rect;
         ::GetWindowRect(hwnd, &window_rect);
         ::SetWindowPos(container_window_, hwnd,
                        window_rect.left,
                        window_rect.top,
                        window_rect.right - window_rect.left,
                        window_rect.bottom - window_rect.top,
                        SWP_NOACTIVATE | SWP_SHOWWINDOW);

         for (auto& handle : unity_handles_) {
           handle.Activate();
         }
       }
       break;
     }
     case WM_ENTERSIZEMOVE: {
       is_in_sizemove_ = true;
       break;
     }
     case WM_EXITSIZEMOVE: {
       is_in_sizemove_ = false;

       {
         RECT window_rect;
         ::GetWindowRect(hwnd, &window_rect);
         ::SetWindowPos(container_window_, hwnd,
                        window_rect.left,
                        window_rect.top,
                        window_rect.right - window_rect.left,
                        window_rect.bottom - window_rect.top,
                        SWP_NOACTIVATE);
       }

       for (auto& handle : unity_handles_) {
         handle.Activate();
       }

       BringFlutterToFront();
       break;
     }
     case WM_MOVE:
     case WM_MOVING:
     case WM_WINDOWPOSCHANGED: {
       RECT window_rect;
       ::GetWindowRect(hwnd, &window_rect);
       if (window_rect.right - window_rect.left > 0 &&
           window_rect.bottom - window_rect.top > 0) {
         ::SetWindowPos(container_window_, hwnd,
                        window_rect.left,
                        window_rect.top,
                        window_rect.right - window_rect.left,
                        window_rect.bottom - window_rect.top,
                        SWP_NOACTIVATE);

         if (::IsIconic(hwnd)) {
           SetWindowComposition(hwnd, ACCENT_DISABLED, 0);
           ::ShowWindow(container_window_, SW_HIDE);
           was_window_hidden_due_to_minimize_ = true;
         }
       }
       break;
     }
     case WM_CLOSE: {
       ::SendMessage(container_window_, WM_CLOSE, 0, 0);
       break;
     }
     default:
       break;
   }
    return std::nullopt;
  }
}