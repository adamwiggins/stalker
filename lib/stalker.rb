require 'beanstalk-client'
require 'json'

module Stalker
	extend self

	def enqueue(job, args={})
		beanstalk.use find_priority(job)
		beanstalk.put [ job, args ].to_json
	end

	def priority(p, &block)
		@@priority = p.to_s
		block.call
		@@priority = nil
	end

	def job(j, &block)
		@@priority ||= 'default'
		@@priorities ||= {}
		@@priorities[j] = @@priority

		@@handlers ||= {}
		@@handlers[j] = block
	end

	def work(priorities=['all'])
		if Array(priorities) == [ 'all' ]
			priorities = @@priorities.values.uniq
		end

		beanstalk.list_tubes_watched.each { |tube| beanstalk.ignore(tube) }
		priorities.each { |priority| beanstalk.watch(priority) }

		loop do
			work_one_job
		end
	end

	class NoSuchJob < RuntimeError; end

	def work_one_job
		job = beanstalk.reserve
		name, args = JSON.parse job.body
		handler = @@handlers[name]
		raise(NoSuchJob, name) unless handler
		handler.call(args)
		job.delete
	rescue => e
		STDERR.puts exception_message(e)
		job.bury
	end

	def jobs(priorities=['all'])
		jobs = []
		@@priorities.each do |job, priority|
			jobs << job if priorities == %w(all) or priorities.include? priority
		end
		jobs
	end

	class NoJobsDefined < RuntimeError; end

	def find_priority(job)
		raise NoJobsDefined unless defined?(@@priorities)
		@@priorities[job] or raise(NoSuchJob, job)
	end

	def beanstalk
		@@beanstalk ||= Beanstalk::Pool.new([ 'localhost:11300' ])
	end

	def exception_message(e)
		msg = [ "Exception #{e.class} -> #{e.message}" ]

		base = File.expand_path(Dir.pwd) + '/'
		e.backtrace.each do |t|
			msg << "   #{File.expand_path(t).gsub(/#{base}/, '')}"
		end

		msg.join("\n")
	end
end
