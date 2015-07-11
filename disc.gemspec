require_relative "lib/disc/version"

Gem::Specification.new do |s|
  s.name              = 'disc'
  s.version           = Disc::VERSION
  s.summary           = 'A simple and powerful Disque job implementation'
  s.description       = ''
  s.authors           = ['pote']
  s.email             = ['pote@tardis.com.uy']
  s.homepage          = 'https://github.com/pote/disque-job'
  s.license           = 'MIT'
  s.files             = `git ls-files`.split("\n")

  s.executables.push('disc')
  s.add_dependency('disque', '~> 0.0.6')
  s.add_dependency('msgpack', '~> 0.6.1')
end
