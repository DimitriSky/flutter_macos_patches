Pod::Spec.new do |s|
  s.name = 'webview_hover_guard'
  s.version = '0.1.0'
  s.summary = 'Keeps web page hover under the mouse in Flutter macOS WebViews.'
  s.description = 'Skips the Flutter engine re-adding an already attached platform view container on every frame.'
  s.homepage = 'https://github.com/DimitriSky/flutter_macos_patches'
  s.license = { :type => 'Proprietary', :file => '../LICENSE' }
  s.author = 'WebView Hover Guard contributors'
  s.source = { :path => '.' }
  s.source_files = 'webview_hover_guard/Sources/webview_hover_guard/**/*.swift'
  s.resource_bundles = { 'webview_hover_guard_privacy' => ['webview_hover_guard/Sources/webview_hover_guard/PrivacyInfo.xcprivacy'] }
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
