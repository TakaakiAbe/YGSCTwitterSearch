platform :ios, "8.0" 
pod 'Toast'
pod 'NSDate-Escort'
pod "Realm"
pod 'AFNetworking', '~> 2.5'

post_install do |installer_representation|
  installer_representation.project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
    end
  end
end