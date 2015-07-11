Gem::Specification.new do |s|
  s.name              = 'disc'
  s.version           = '0.0.4'
  s.summary           = 'A simple disque and powerful job implementation'
  s.description       = ''
  s.authors           = ['pote']
  s.email             = ['pote@tardis.com.uy']
  s.homepage          = 'https://github.com/pote/disque-job'
  s.license           = 'MIT'
  s.files             = `git ls-files`.split("\n")

  s.executables.push('disc')
  s.add_dependency('disque')
  s.add_dependency('msgpack')
end
