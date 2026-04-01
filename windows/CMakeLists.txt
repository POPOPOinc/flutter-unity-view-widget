cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "flutter_unity_widget")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_unity_widget_plugin")

# Plugin class sources (reusable for tests)
list(APPEND PLUGIN_SOURCES
  "flutter_unity_widget_plugin.cpp"
  "flutter_unity_widget_plugin.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/flutter_unity_widget/flutter_unity_widget_plugin.h"
  "flutter_unity_widget_plugin_c_api.cpp"
  "native_window_container.cpp"
  "window_composition_utility.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_compile_options(${PLUGIN_NAME} PRIVATE "/utf-8")

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}")

# shlwapi.lib: PathRemoveFileSpecW (DLL search path computation)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin shlwapi.lib)

# List of absolute paths to libraries that should be bundled with the plugin
set(flutter_unity_widget_bundled_libraries
  ""
  PARENT_SCOPE
)
