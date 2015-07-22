Pod::Spec.new do |spec|
  spec.name         = 'JavascriptEngine'
  spec.version      = '0.0.2'
  spec.license      = { :type => 'MIT' }
  spec.homepage     = 'https://github.com/pcperini/JavascriptEngine'
  spec.authors      = { 'Patrick Perini' => 'pcperini@gmail.com' }
  spec.summary      = 'A Swift interface for bridging to WebKit Javascript, without wanting to kill yourself or others.'
  spec.source       = { :git => 'https://github.com/pcperini/JavascriptEngine.git', :tag => 'v0.0.2' }
  spec.source_files = 'JavascriptEngine/JSEngine.swift'
  spec.platform = :ios, "8.0"
  spec.dependency = 'AFNetworking'
end