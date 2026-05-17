#!/usr/bin/env ruby
# Adds the DocShelfShareExtension target to Runner.xcodeproj.
# Run once: ruby ios/add_share_extension.rb
# Safe to re-run — it checks before adding.

require 'xcodeproj'

PROJECT_PATH  = File.expand_path('../ios/Runner.xcodeproj', __dir__)
EXT_NAME      = 'DocShelfShareExtension'
EXT_BUNDLE_ID = 'com.docshelf.myapp.ShareExtension'
EXT_DIR       = File.expand_path('../ios/DocShelfShareExtension', __dir__)
DEPLOY_TARGET = '13.0'

project = Xcodeproj::Project.open(PROJECT_PATH)

# ── Guard: don't add twice ─────────────────────────────────────────────
if project.targets.any? { |t| t.name == EXT_NAME }
  puts "✓ #{EXT_NAME} already exists — nothing to do."
  exit 0
end

# ── 1. Create the extension target ────────────────────────────────────
ext_target = project.new_target(
  :app_extension,
  EXT_NAME,
  :ios,
  DEPLOY_TARGET,
  project.products_group,
  :swift
)

# ── 2. Build settings ──────────────────────────────────────────────────
['Debug', 'Release'].each do |config_name|
  config = ext_target.build_configuration_list[config_name]
  settings = config.build_settings

  settings['PRODUCT_BUNDLE_IDENTIFIER']   = EXT_BUNDLE_ID
  settings['SWIFT_VERSION']               = '5.0'
  settings['IPHONEOS_DEPLOYMENT_TARGET']  = DEPLOY_TARGET
  settings['TARGETED_DEVICE_FAMILY']      = '1,2'
  settings['CODE_SIGN_STYLE']             = 'Automatic'
  settings['DEVELOPMENT_TEAM']            = '$(inherited)'
  settings['SKIP_INSTALL']                = 'YES'
  settings['SWIFT_OPTIMIZATION_LEVEL']    = config_name == 'Debug' ? '-Onone' : '-O'
  settings['ENABLE_BITCODE']              = 'NO'

  settings['INFOPLIST_FILE'] =
    "DocShelfShareExtension/Info.plist"
  settings['CODE_SIGN_ENTITLEMENTS'] =
    "DocShelfShareExtension/DocShelfShareExtension.entitlements"

  # Flutter build name/number from environment (set by flutter build)
  settings['FLUTTER_BUILD_NAME']   = '$(FLUTTER_BUILD_NAME)'
  settings['FLUTTER_BUILD_NUMBER'] = '$(FLUTTER_BUILD_NUMBER)'
end

# ── 3. Add source file ─────────────────────────────────────────────────
sources_group = project.main_group
  .find_subpath('DocShelfShareExtension', true)

swift_ref = sources_group.new_reference('ShareViewController.swift')
swift_ref.source_tree = '<group>'
swift_ref.last_known_file_type = 'sourcecode.swift'
ext_target.add_file_references([swift_ref])

# Add Info.plist (resources)
plist_ref = sources_group.new_reference('Info.plist')
plist_ref.source_tree = '<group>'
plist_ref.last_known_file_type = 'text.plist.xml'
ext_target.resources_build_phase.add_file_reference(plist_ref)

# Add entitlements (not a build phase file, just a group reference)
ent_ref = sources_group.new_reference('DocShelfShareExtension.entitlements')
ent_ref.source_tree = '<group>'
ent_ref.last_known_file_type = 'text.plist.entitlements'

# ── 4. Embed extension in Runner ──────────────────────────────────────
runner = project.targets.find { |t| t.name == 'Runner' }
raise "Runner target not found!" unless runner

embed_phase = runner.build_phases.find do |p|
  p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
    p.name == 'Embed App Extensions'
end

unless embed_phase
  embed_phase = runner.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.dst_subfolder_spec = '13' # PlugIns folder
end

ext_product = ext_target.product_reference
embed_ref = embed_phase.add_file_reference(ext_product)
embed_ref.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# ── 5. Add Runner entitlements to Runner target's build settings ───────
['Debug', 'Release'].each do |config_name|
  config = runner.build_configuration_list[config_name]
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] =
    'Runner/Runner.entitlements'
end

# ── 6. Save ────────────────────────────────────────────────────────────
project.save
puts "✅ Added #{EXT_NAME} target to #{PROJECT_PATH}"
puts "   Bundle ID : #{EXT_BUNDLE_ID}"
puts "   Embed     : Runner → Embed App Extensions"
puts "   Entitle   : Runner.entitlements + DocShelfShareExtension.entitlements"
