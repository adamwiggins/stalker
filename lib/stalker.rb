require 'beanstalk-client'
require 'json'

module Stalker
	extend self

	def enqueue(job, args={})
		beanstalk.use find_priority(job)
		beanstalk.put [ job, args ].to_json
	end

	def priority(p, &block)
		@@handlers ||= {}
		@@priority = p.to_s
		block.call
		@@priority = nil
	end

	def job(j, &block)
		@@priority ||= 'default'
		@@priorities ||= {}
		@@priorities[j] = @@priority

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
	end

	def jobs(priorities=['all'])
		jobs = []
		@@priorities.each do |job, priority|
			jobs << job if priorities == %w(all) or priorities.include? priority
		end
		jobs
	end

	def find_priority(job)
		@@priorities[job] or raise(NoSuchJob, job)
	end

	def beanstalk
		@@beanstalk ||= Beanstalk::Pool.new([ 'localhost:11300' ])
	end
end
