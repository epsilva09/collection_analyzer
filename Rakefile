# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

desc "Run RuboCop lint checks"
task :lint do
	system("bin/rubocop") || abort("RuboCop failed")
end

namespace :lint do
	desc "Run RuboCop safe auto-corrections"
	task :fix do
		system("bin/rubocop -a") || abort("RuboCop auto-correct failed")
	end
end
