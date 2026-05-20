Pod::Spec.new do |s|
  s.name             = 'zendesk_messaging_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for Zendesk Messaging SDK.'
  s.homepage         = 'https://zendesk.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Zendesk' => 'mobile@zendesk.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'ZendeskSDKMessaging', '~> 2.38'
  s.platform         = :ios, '14.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.5'
end
