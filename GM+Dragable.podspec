Pod::Spec.new do |s|
  s.name         = "GM+Dragable"
  s.version      = "0.2.6"
  s.summary      = "A DragableView extension for GM"
  s.homepage     = "https://github.com/shaokui-gu/GM-Dragable"
  s.license      = 'MIT'
  s.author       = { 'gushaokui' => 'gushaoakui@126.com' }
  s.source       = { :git => "https://github.com/shaokui-gu/GM-Dragable.git" }
  s.source_files = 'Sources/*.swift'
  s.swift_versions = ['5.2', '5.3', '5.4']
  s.dependency 'GM'
  s.dependency 'SnapKit', '5.0.1'
  s.requires_arc = true
end
