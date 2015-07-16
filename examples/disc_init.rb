$:.unshift('lib')
Dir.glob("./examples/**/*.rb") { |f| require f }
