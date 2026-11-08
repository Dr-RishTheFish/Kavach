require 'xcodeproj'
root = File.expand_path('..', __dir__)
path = File.join(root, 'Kavach.xcodeproj')
abort 'Project already exists; edit it in Xcode rather than overwriting.' if File.exist?(path)
project = Xcodeproj::Project.new(path)
app = project.new_target(:application, 'Kavach', :ios, '17.0')
tests = project.new_target(:unit_test_bundle, 'KavachTests', :ios, '17.0')
ui = project.new_target(:ui_test_bundle, 'KavachUITests', :ios, '17.0')
tests.add_dependency(app)
ui.add_dependency(app)
config_group = project.main_group.new_group('Configuration', 'Configuration')
config = config_group.new_file('App.xcconfig')
[[app, 'Kavach'], [tests, 'KavachTests'], [ui, 'KavachUITests']].each do |target, dir|
  group = project.main_group.new_group(dir, dir)
  Dir.glob(File.join(root, dir, '**', '*.swift')).sort.each do |file|
    ref = group.new_file(file.delete_prefix(File.join(root, dir) + '/'))
    target.source_build_phase.add_file_reference(ref)
  end
  target.build_configurations.each do |c|
    c.base_configuration_reference = config
    c.build_settings.merge!({
      'SWIFT_VERSION' => '5.0', 'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
      'GENERATE_INFOPLIST_FILE' => 'YES', 'TARGETED_DEVICE_FAMILY' => '1',
      'CODE_SIGN_STYLE' => 'Automatic', 'CURRENT_PROJECT_VERSION' => '1',
      'MARKETING_VERSION' => '0.1.0', 'ENABLE_USER_SCRIPT_SANDBOXING' => 'YES'
    })
    c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = target == app ? '$(KAVACH_BUNDLE_IDENTIFIER)' : "$(KAVACH_BUNDLE_IDENTIFIER).#{dir}"
  end
end
app.build_configurations.each do |c|
  c.build_settings['INFOPLIST_FILE'] = "Configuration/Info-#{c.name}.plist"
  c.build_settings.merge!({
    'INFOPLIST_KEY_CFBundleDisplayName' => 'kavach',
    'INFOPLIST_KEY_UILaunchScreen_Generation' => 'YES',
    'INFOPLIST_KEY_UIApplicationSceneManifest_Generation' => 'YES',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations' => 'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
    'ENABLE_PREVIEWS' => 'YES'
  })
end
tests.build_configurations.each do |c|
  c.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/Kavach.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Kavach'
  c.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
end
ui.build_configurations.each { |c| c.build_settings['TEST_TARGET_NAME'] = 'Kavach' }
fixtures = project.main_group['KavachTests'].new_group('Fixtures', 'Fixtures')
Dir.glob(File.join(root, 'KavachTests/Fixtures/*.json')).each do |file|
  tests.resources_build_phase.add_file_reference(fixtures.new_file(File.basename(file)))
end
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(tests)
scheme.add_test_target(ui)
scheme.set_launch_target(app)
scheme.save_as(path, 'Kavach', true)
project.files.select { |ref| ref.path&.end_with?('Foundation.framework') }.each do |ref|
  ref.path = 'System/Library/Frameworks/Foundation.framework'
  ref.source_tree = 'SDKROOT'
end
project.save
puts path
