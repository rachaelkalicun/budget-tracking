require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test
