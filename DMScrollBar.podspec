Pod::Spec.new do |s|
  s.name                  = 'DMScrollBar'
  s.version               = '2.1.3'
  s.summary               = 'Customizable Scroll Bar for Scroll view.'
  s.description           = "Customizable Scroll Bar for Scroll View with additional info label appearing during the scroll."
  s.homepage              = 'https://github.com/batanus/DMScrollBar'
  s.screenshots           = 'https://user-images.githubusercontent.com/25244017/209937470-d76a558c-6350-4d96-a142-13a6ef32e0f8.gif', 'https://user-images.githubusercontent.com/25244017/209937479-e7acbbd1-fba1-4fa8-a34f-9bb4b3ee790e.gif', 'https://user-images.githubusercontent.com/25244017/209937517-be2e6f54-53f9-447d-ad38-4fab39624551.gif'
  s.license               = { :type => 'MIT', :file => 'LICENSE' }
  s.author                = { 'Dmitrii Medvedev' => 'dima7711@gmail.com' }
  s.source                = { :git => 'https://github.com/batanus/DMScrollBar.git', :tag => s.version.to_s }
  s.swift_versions        =  ['5.7']
  s.source_files          = 'DMScrollBar/**/*'
  s.ios.deployment_target = '14.0'
end