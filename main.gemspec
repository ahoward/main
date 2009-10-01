## main.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "main"
  spec.version = "2.9.3"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "main"

  spec.files = ["lib", "lib/main", "lib/main/base.rb", "lib/main/cast.rb", "lib/main/factories.rb", "lib/main/getoptlong.rb", "lib/main/logger.rb", "lib/main/mode.rb", "lib/main/parameter.rb", "lib/main/softspoken.rb", "lib/main/stdext.rb", "lib/main/usage.rb", "lib/main/util.rb", "lib/main.rb", "main.gemspec", "Rakefile", "README", "README.erb", "samples", "samples/a.rb", "samples/b.rb", "samples/c.rb", "samples/d.rb", "samples/e.rb", "samples/f.rb", "samples/g.rb", "samples/h.rb", "test", "test/main.rb", "TODO"]
  spec.executables = []
  
  
  spec.require_path = "lib"
  

  spec.has_rdoc = true
  spec.test_files = "test/main.rb"
  #spec.add_dependency 'lib', '>= version'
  #spec.add_dependency 'fattr'

  spec.extensions.push(*[])

  spec.rubyforge_project = "codeforpeople"
  spec.author = "Ara T. Howard"
  spec.email = "ara.t.howard@gmail.com"
  spec.homepage = "http://github.com/ahoward/main/tree/master"
end
