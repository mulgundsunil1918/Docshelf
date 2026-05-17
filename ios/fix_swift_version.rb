#!/usr/bin/env ruby
# Ensure DocShelfShareExtension has SWIFT_VERSION = 5.0 in all configurations.
# Run after pod install if the SWIFT_VERSION conflict appears.
require 'xcodeproj'

PROJECT_PATH = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)
ext = project.targets.find { |t| t.name == 'DocShelfShareExtension' }
exit 0 unless ext

ext.build_configuration_list.build_configurations.each do |c|
  c.build_settings['SWIFT_VERSION'] = '5.0'
end
project.save
puts "✅ Set SWIFT_VERSION = 5.0 on DocShelfShareExtension"
