desc 'Increment version, build a gem, push to RubyGems and commit the change to gemspec'
task :build do
  unless `git status`.include?('nothing to commit')
    puts "Working copy is not clean.\nYou should commit before trying to build the gem."
    Process.exit(1)
  end
  
  gemspec_path = File.join(File.dirname(__FILE__), 'atech_cloud.gemspec')
  gemspec = File.read(gemspec_path)
  version = nil
  gemspec.gsub!(/s.version = \"1.0.(\d+)\"/) do
    version = "1.0.#{$1.to_i + 1}"
    "s.version = \"#{version}\""
  end
  File.open(gemspec_path, 'w') {|f| f.write(gemspec)}
  system "gem build #{gemspec_path}"
  gem_path = "atech_cloud-#{version}.gem"
  system "gem push #{gem_path}"
  system "rm #{gem_path}"
  system "git add atech_cloud.gemspec"
  system "git commit -m 'bump gem version to #{version}'"
  
  puts
  puts "Tagging..."
  system "git tag -a v#{version} -m 'tagging #{version}'"
  puts "You can now push the repository if you want..."
end
