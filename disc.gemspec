Gem::Specification.new do |s|
  s.name              = "disque-job"
  s.version           = "0.0.1"
  s.summary           = "A simple disque job implementation"
  s.description       = ""
  s.authors           = ["pote"]
  s.email             = ["pote@tardis.com.uy"]
  s.homepage          = "https://github.com/pote/disque-job"
  s.license           = "MIT"

  s.files = `git ls-files`.split("\n")

  s.add_dependency "disque"
  s.add_development_dependency "cutest"
end
