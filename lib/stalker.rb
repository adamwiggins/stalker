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
		@@priority = p.to_sym
		block.call
		@priority = nil
	end

	def job(j, &block)
		@priority ||= :default
		@@handlers[@@priority] ||= {}
		@@handlers[@@priority][j] = block
	end

	def run(priority)
		loop do
			beanstalk.watch(priority)
			work_job(priority)
		end
	end

	def work_job(priority)
		job = beanstalk.reserve
		name, args = JSON.parse job.body
		handler = @@handlers[priority.to_sym][name]
		raise "No #{priority} handler for #{name}" unless handler
		handler.call(args)
		job.delete
	end

	class NoSuchJob < RuntimeError; end

	def find_priority(job)
		@@handlers.each do |priority, jobs|
			jobs.keys.each do |j|
				return priority if j == job
			end
		end
		raise NoSuchJob, job
	end

	def beanstalk
		@@beanstalk ||= Beanstalk::Pool.new([ 'localhost:11300' ])
	end
end
