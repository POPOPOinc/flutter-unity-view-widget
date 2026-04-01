#ifndef WINDOW_COMPOSITION_UTILITY_H_
#define WINDOW_COMPOSITION_UTILITY_H_

#include <dwmapi.h>

#include <cstdint>

namespace flutter_unity_widget {

  typedef enum _ACCENT_STATE {
    ACCENT_DISABLED = 0,
    ACCENT_ENABLE_GRADIENT = 1,
    ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
    ACCENT_ENABLE_BLURBEHIND = 3,
    ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
    ACCENT_ENABLE_HOSTBACKDROP = 5,
    ACCENT_INVALID_STATE = 6
  } ACCENT_STATE;

  RTL_OSVERSIONINFOW GetWindowsVersion();
  void SetWindowComposition(HWND window, ACCENT_STATE accent_state, int32_t gradient_color);

}
#endif