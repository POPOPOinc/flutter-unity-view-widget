#ifndef LOG_UTIL_H_
#define LOG_UTIL_H_

#include <cstdarg>
#include <cstdio>
#include <windows.h>

namespace flutter_unity_widget {

  inline void DebugLog(const char* fmt, ...) {
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    OutputDebugStringA(buf);
    OutputDebugStringA("\n");
  }

}  // namespace flutter_unity_widget

#endif