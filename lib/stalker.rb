require 'beanstalk-client'
require 'json'

module Stalker
	extend self

	$jobs = []

	def enqueue(name, args={})
		beanstalk.put([ name, args ].to_json)
	end

	def job(name, &block)
		@@handlers ||= {}
		@@handlers[name] = block
	end

	def run
		loop { work_job }
	end

	def work_job
		job = beanstalk.reserve
		name, args = JSON.parse job.body
		handler = @@handlers[name]
		raise "No handler for #{name}" unless handler
		handler.call(args)
		job.delete
	end

	def beanstalk
		@@beanstalk ||= Beanstalk::Pool.new([ 'localhost:11300' ])
	end
end
