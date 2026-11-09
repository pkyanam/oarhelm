require 'xcodeproj'
require 'pathname'
root = File.expand_path('..', __dir__)
p = Xcodeproj::Project.new(File.join(root, 'Oarhelm.xcodeproj'))
t = p.new_target(:application, 'Oarhelm', :ios, '18.0')
g = p.main_group.new_group('Oarhelm', 'Oarhelm')
Dir.glob(File.join(root,'Oarhelm','*.swift')).sort.each { |f| t.source_build_phase.add_file_reference(g.new_file(File.basename(f))) }
t.resources_build_phase.add_file_reference(g.new_file('Assets.xcassets'))
r = g.new_group('Resources','Resources')
Dir.glob(File.join(root,'Oarhelm','Resources','*')).sort.each { |f| t.resources_build_phase.add_file_reference(r.new_file(File.basename(f))) if File.file?(f) }
t.build_configurations.each do |c|
 c.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER'=>'com.preetham.oarhelm','PRODUCT_NAME'=>'Oarhelm','SWIFT_VERSION'=>'6.0','SWIFT_STRICT_CONCURRENCY'=>'complete','TARGETED_DEVICE_FAMILY'=>'1,2','GENERATE_INFOPLIST_FILE'=>'YES','INFOPLIST_KEY_CFBundleDisplayName'=>'Oarhelm','INFOPLIST_FILE'=>'Oarhelm/Info.plist','MARKETING_VERSION'=>'0.1.0','CURRENT_PROJECT_VERSION'=>'6','ASSETCATALOG_COMPILER_APPICON_NAME'=>'AppIcon','DEVELOPMENT_TEAM'=>'6D56G8D849','CODE_SIGN_STYLE'=>'Automatic','ENABLE_USER_SCRIPT_SANDBOXING'=>'YES'})
end
p.save
s = Xcodeproj::XCScheme.new
s.add_build_target(t)
s.set_launch_target(t)
s.save_as(p.path,'Oarhelm',true)
