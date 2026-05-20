//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <dynamic_color/dynamic_color_plugin_c_api.h>
#include <flutter_secure_storage_windows/flutter_secure_storage_windows_plugin.h>
#include <fullscreen_window/fullscreen_window_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>
#include <webview_win_floating/webview_win_floating_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  DynamicColorPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DynamicColorPluginCApi"));
  FlutterSecureStorageWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterSecureStorageWindowsPlugin"));
  FullscreenWindowPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FullscreenWindowPluginCApi"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
  WebviewWinFloatingPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WebviewWinFloatingPluginCApi"));
}
