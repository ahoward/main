## main.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "main"
  spec.version = "6.2.2"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "main"
  spec.description = "a class factory and dsl for generating command line programs real quick"
  spec.license = "Ruby"

  spec.files =
["README",
 "README.erb",
 "Rakefile",
 "TODO",
 "a.rb",
 "lib",
 "lib/main",
 "lib/main.rb",
 "lib/main/cast.rb",
 "lib/main/daemon.rb",
 "lib/main/dsl.rb",
 "lib/main/factories.rb",
 "lib/main/getoptlong.rb",
 "lib/main/logger.rb",
 "lib/main/mode.rb",
 "lib/main/parameter.rb",
 "lib/main/program",
 "lib/main/program.rb",
 "lib/main/program/class_methods.rb",
 "lib/main/program/instance_methods.rb",
 "lib/main/softspoken.rb",
 "lib/main/stdext.rb",
 "lib/main/test.rb",
 "lib/main/usage.rb",
 "lib/main/util.rb",
 "main.gemspec",
 "samples",
 "samples/a.rb",
 "samples/b.rb",
 "samples/c.rb",
 "samples/d.rb",
 "samples/e.rb",
 "samples/f.rb",
 "samples/g.rb",
 "samples/h.rb",
 "samples/j.rb",
 "test",
 "test/main_test.rb"]

  spec.executables = []
  
  spec.require_path = "lib"

  spec.test_files = nil

  
    spec.add_dependency(*["chronic", "~> 0.6", ">= 0.6.2"])
  
    spec.add_dependency(*["fattr", "~> 2.2", ">= 2.2.0"])
  
    spec.add_dependency(*["arrayfields", "~> 4.7", ">= 4.7.4"])
  
    spec.add_dependency(*["map", "~> 6.1", ">= 6.1.0"])
  

  spec.extensions.push(*[])

  spec.rubyforge_project = "codeforpeople"
  spec.author = "Ara T. Howard"
  spec.email = "ara.t.howard@gmail.com"
  spec.homepage = "https://github.com/ahoward/main"
end
