#!/usr/bin/env ruby
# frozen_string_literal: true

# Idempotent: adds TaktHomeWidget WidgetKit extension + App Group entitlements.
require 'xcodeproj'

IOS = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(IOS, 'Runner.xcodeproj')
WIDGET_NAME = 'TaktHomeWidget'
TEAM = '3NQ93DY69B'
MAIN_BUNDLE = 'ru.gadzhilaev.takt'
WIDGET_BUNDLE = "#{MAIN_BUNDLE}.#{WIDGET_NAME}"

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' }
abort('Runner target not found') unless runner

widget_target = project.targets.find { |t| t.name == WIDGET_NAME }

unless widget_target
  widget_target = project.new_target(:app_extension, WIDGET_NAME, :ios, '15.0')
  widget_target.product_type = 'com.apple.product-type.app-extension'

  widget_group = project.main_group.find_subpath(WIDGET_NAME, true)
  widget_group.set_source_tree('<group>')
  widget_group.set_path(WIDGET_NAME)

  swift_ref = widget_group.new_file('TaktHomeWidget.swift')
  widget_group.new_file('Info.plist')
  widget_group.new_file('TaktHomeWidget.entitlements')
  assets_ref = widget_group.new_file('Assets.xcassets')

  widget_target.source_build_phase.clear
  widget_target.add_file_references([swift_ref])
  widget_target.resources_build_phase.clear if widget_target.resources_build_phase
  widget_target.add_resources([assets_ref])

  # Copy Profile build configuration from Debug if missing
  debug_cfg = widget_target.build_configurations.find { |c| c.name == 'Debug' }
  unless widget_target.build_configurations.find { |c| c.name == 'Profile' }
    profile = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
    profile.name = 'Profile'
    profile.build_settings = debug_cfg.build_settings.merge({})
    widget_target.build_configuration_list.build_configurations << profile
  end

  widget_settings = {
    'PRODUCT_BUNDLE_IDENTIFIER' => WIDGET_BUNDLE,
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => "#{WIDGET_NAME}/Info.plist",
    'CODE_SIGN_ENTITLEMENTS' => "#{WIDGET_NAME}/TaktHomeWidget.entitlements",
    'CODE_SIGN_STYLE' => 'Automatic',
    'DEVELOPMENT_TEAM' => TEAM,
    'IPHONEOS_DEPLOYMENT_TARGET' => '15.0',
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)',
      '@executable_path/Frameworks',
      '@executable_path/../../Frameworks',
    ],
    'SKIP_INSTALL' => 'YES',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'SWIFT_VERSION' => '5.0',
    'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
    'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'CLANG_ENABLE_MODULES' => 'YES',
  }

  widget_target.build_configurations.each do |config|
    config.build_settings.merge!(widget_settings)
    if config.name == 'Debug'
      config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
      config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
    end
  end

  embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
  unless embed
    embed = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    embed.name = 'Embed Foundation Extensions'
    embed.dst_path = ''
    embed.dst_subfolder_spec = '13'
    runner.build_phases << embed
  end

  already = embed.files.any? { |bf| bf.file_ref&.path == "#{WIDGET_NAME}.appex" }
  unless already
    bf = embed.add_file_reference(widget_target.product_reference)
    bf.settings = { 'ATTRIBUTES' => %w[RemoveHeadersOnCopy] }
  end

  runner.add_dependency(widget_target) unless runner.dependencies.any? { |d| d.target == widget_target }
  puts "Created target #{WIDGET_NAME}"
else
  puts "#{WIDGET_NAME} already exists"
end

runner_group = project.main_group.find_subpath('Runner', false)
unless runner_group.files.any? { |f| f.path == 'Runner.entitlements' }
  runner_group.new_file('Runner.entitlements')
end

runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  config.build_settings['DEVELOPMENT_TEAM'] ||= TEAM
end

project.save
puts 'Saved Runner.xcodeproj'
puts "Widget bundle: #{WIDGET_BUNDLE}"
