Pod::Spec.new do |s|
  s.name                  = 'DMScrollBar'
  s.version               = '1.0.0'
  s.summary               = 'Customizable Scroll Bar for Scroll view.'
  s.description           = "Customizable Scroll Bar for Scroll View with additional info label appearing during the scroll."
  s.homepage              = 'https://github.com/batanus/DMScrollBar'
  # s.screenshots           = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license               = { :type => 'MIT', :file => 'LICENSE' }
  s.author                = { 'Dmitrii Medvedev' => 'dima7711@gmail.com' }
  s.source                = { :git => 'https://github.com/batanus/DMScrollBar.git', :tag => s.version.to_s }
  s.swift_versions        =  ['5.7']
  s.source_files          = 'DMScrollBar/**/*'
  s.ios.deployment_target = '14.0'
end