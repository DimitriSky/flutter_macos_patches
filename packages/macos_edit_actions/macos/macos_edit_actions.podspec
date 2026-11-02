Pod::Spec.new do |s|
  s.name = 'macos_edit_actions'
  s.version = '0.1.0'
  s.summary = 'Standard edit commands (paste, copy, cut, select all) for Flutter macOS text fields.'
  s.description = 'Adds paste:, copy:, cut: and selectAll: that act on the Flutter editing model to the engine text input view.'
  s.homepage = 'https://github.com/DimitriSky/flutter_macos_patches'
  s.license = { :type => 'Proprietary', :file => '../LICENSE' }
  s.author = 'Flutter macOS patches contributors'
  s.source = { :path => '.' }
  s.source_files = 'macos_edit_actions/Sources/macos_edit_actions/**/*.swift'
  s.resource_bundles = { 'macos_edit_actions_privacy' => ['macos_edit_actions/Sources/macos_edit_actions/PrivacyInfo.xcprivacy'] }
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
