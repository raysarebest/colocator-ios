Pod::Spec.new do |s|
  s.name                  = 'CCLocation'
  s.version               = '2.1.2'
  s.summary               = 'The CrowdConnected colocator iOS library'
  s.homepage              = 'https://github.com/crowdconnected/colocator-ios.git'
  s.social_media_url      = 'https://twitter.com/crowdconnected'

  s.author                = { 'CrowdConnected Ltd' => 'mail@crowdconnected.com' }
  s.source                = { :git => 'https://github.com/crowdconnected/colocator-ios.git', :tag => s.version.to_s }
  s.license               = { :type => 'Copyright', :text => 'Copyright (c) 2018 Crowd Connected Ltd' }

  s.documentation_url     = 'https://developers.colocator.net'

  s.source_files          = 'CCLocation/**/*.swift'
  s.resources              = 'CCLocation/certificate.der'
  s.module_name           = 'CCLocation'

  s.ios.deployment_target = '9.0'

  s.frameworks            = 'CoreLocation', 'UIKit', 'CoreBluetooth'

  s.dependency 'SocketRocket', '0.4.2'
  s.dependency 'SwiftProtobuf', '1.2.0'
  s.dependency 'ReSwift', '4.0.1'
  s.dependency 'TrueTime', '5.0.0'
  s.dependency 'ReachabilitySwift', '4.3.1'
end
