require 'beanstalk-client'
require 'json'
require 'uri'

module Stalker
	extend self

	def enqueue(job, args={})
		beanstalk.use job
		beanstalk.put [ job, args ].to_json
	end

	def job(j, &block)
		@@handlers ||= {}
		@@handlers[j] = block
	end

	class NoJobsDefined < RuntimeError; end
	class NoSuchJob < RuntimeError; end

	def work(jobs=nil)
		raise NoJobsDefined unless defined?(@@handlers)

		jobs ||= all_jobs

		jobs.each do |job|
			raise(NoSuchJob, job) unless @@handlers[job]
		end

		log "Working #{jobs.size} jobs: [ #{jobs.join(' ')} ]"

		beanstalk.list_tubes_watched.each { |tube| beanstalk.ignore(tube) }
		jobs.each { |job| beanstalk.watch(job) }

		loop do
			work_one_job
		end
	end

	def work_one_job
		job = beanstalk.reserve
		name, args = JSON.parse job.body
		log_job_begin(name, args)
		handler = @@handlers[name]
		raise(NoSuchJob, name) unless handler
		handler.call(args)
		job.delete
		log_job_end(name)
	rescue => e
		STDERR.puts exception_message(e)
		job.bury
	end

	def log_job_begin(name, args)
		args_flat = unless args.empty?
			'(' + args.inject([]) do |accum, (key,value)|
				accum << "#{key}=#{value}"
			end.join(' ') + ')'
		else
			''
		end

		log [ "->", name, args_flat ].join(' ')
		@job_begun = Time.now
	end

	def log_job_end(name)
		ellapsed = Time.now - @job_begun
		ms = (ellapsed.to_f * 1000).to_i
		log "-> #{name} finished in #{ms}ms"
	end

	def log(msg)
		puts "[#{Time.now}] #{msg}"
	end

	def beanstalk
		@@beanstalk ||= Beanstalk::Pool.new([ beanstalk_host_and_port ])
	end

	def beanstalk_url
		ENV['BEANSTALK_URL'] || 'beanstalk://localhost:11300/'
	end

	class BadURL < RuntimeError; end

	def beanstalk_host_and_port
		uri = URI.parse(beanstalk_url)
		raise(BadURL, beanstalk_url) if uri.scheme != 'beanstalk'
		return "#{uri.host}:#{uri.port}"
	end

	def exception_message(e)
		msg = [ "Exception #{e.class} -> #{e.message}" ]

		base = File.expand_path(Dir.pwd) + '/'
		e.backtrace.each do |t|
			msg << "   #{File.expand_path(t).gsub(/#{base}/, '')}"
		end

		msg.join("\n")
	end

	def all_jobs
		@@handlers.keys
	end
end
