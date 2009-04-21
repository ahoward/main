require 'pathname'

$VERBOSE=nil

def indent s, n = 2
  ws = ' ' * n
  s.gsub %r/^/, ws 
end

template = IO::read 'README.tmpl'

samples = ''
prompt = '~ > '

skip = %w[ e.rb f.rb ]

Dir['sample*/*'].sort.each do |sample|
  next if skip.include? File.basename(sample)

  samples << "\n" << "  <========< #{ sample } >========>" << "\n\n"

  cmd = "cat #{ sample }" 
  samples << indent(prompt + cmd, 2) << "\n\n" 
  samples << indent(`#{ cmd }`, 4) << "\n" 

  cmd = "ruby #{ sample }" 
  samples << indent(prompt + cmd, 2) << "\n\n" 

  cmd = "ruby -Ilib #{ sample }" 
  samples << indent(`#{ cmd } 2>&1`, 4) << "\n" 

  cmd = "ruby #{ sample } --help" 
  samples << indent(prompt + cmd, 2) << "\n\n" 

  cmd = "ruby -Ilib #{ sample } --help" 
  samples << indent(`#{ cmd } 2>&1`, 4) << "\n" 
end

#samples.gsub! %r/^/, '  '

readme  = template.gsub %r/^\s*@samples\s*$/, samples
print readme 
