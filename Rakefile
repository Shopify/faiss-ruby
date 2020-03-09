require "bundler/gem_tasks"
require "rake/testtask"
require "rake/extensiontask"

task default: :test
Rake::TestTask.new do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
  t.warning = false
end

Rake::ExtensionTask.new("faiss") do |ext|
  ext.name = "ext"
  ext.lib_dir = "lib/faiss"
end

# include ext in local installs but not releases
task :remove_ext do
  path = "lib/faiss/ext.bundle"
  File.unlink(path) if File.exist?(path)
end

task :remove_obj do
  path = "ext/faiss/ext.o"
  File.unlink(path) if File.exist?(path)
end

Rake::Task["release:guard_clean"].enhance [:remove_ext, :remove_obj]
Rake::Task["compile"].enhance [:remove_obj]
