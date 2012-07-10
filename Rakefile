require 'jeweler'

Jeweler::Tasks.new do |s|
	s.name = "stalker"
	s.summary = "A job queueing and background workers system using Beanstalkd."
	s.description = "A job queueing and background workers system using Beanstalkd.  Inspired by the Minion gem."
	s.author = "Adam Wiggins"
	s.email = "adam@heroku.com"
	s.homepage = "https://github.com/han/stalker"
	s.executables = [ "stalk" ]
	s.rubyforge_project = "stalker"

	s.add_dependency 'beanstalk-client'
	s.add_dependency 'json_pure'

	s.files = FileList["[A-Z]*", "{bin,lib}/**/*"]
end

Jeweler::GemcutterTasks.new
