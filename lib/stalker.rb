require 'beanstalk-client'
require 'json'
require 'uri'
require 'timeout'

module Stalker
	extend self

	def connect(url)
		@@url = url
		beanstalk
	end

	def enqueue(job, args={}, opts={})
		pri   = opts[:pri]   || 65536
		delay = opts[:delay] || 0
		ttr   = opts[:ttr]   || 120
		beanstalk.use job
		beanstalk.put [ job, args ].to_json, pri, delay, ttr
	rescue Beanstalk::NotConnected => e
		failed_connection(e)
	end

	def job(j, &block)
		@@handlers ||= {}
		@@handlers[j] = block
	end

	def before(&block)
		@@before_handlers ||= []
		@@before_handlers << block
	end

	def error(&blk)
		@@error_handler = blk
	end

	class NoJobsDefined < RuntimeError; end
	class NoSuchJob < RuntimeError; end

	def prep(jobs=nil)
		raise NoJobsDefined unless defined?(@@handlers)
		@@error_handler = nil unless defined?(@@error_handler)

		jobs ||= all_jobs

		jobs.each do |job|
			raise(NoSuchJob, job) unless @@handlers[job]
		end

		log "Working #{jobs.size} jobs: [ #{jobs.join(' ')} ]"

		jobs.each { |job| beanstalk.watch(job) }

		beanstalk.list_tubes_watched.each do |server, tubes|
			tubes.each { |tube| beanstalk.ignore(tube) unless jobs.include?(tube) }
		end
	rescue Beanstalk::NotConnected => e
		failed_connection(e)
	end

	def work(jobs=nil)
		prep(jobs)
		loop { work_one_job }
	end

	class JobTimeout < RuntimeError; end

	def work_one_job
		job = beanstalk.reserve
		name, args = JSON.parse job.body
		log_job_begin(name, args)
		handler = @@handlers[name]
		raise(NoSuchJob, name) unless handler

		begin
			Timeout::timeout(job.ttr - 1) do
				if defined? @@before_handlers and @@before_handlers.respond_to? :each
					@@before_handlers.each do |block|
						block.call(name)
					end
				end
				handler.call(args)
			end
		rescue Timeout::Error
			raise JobTimeout, "#{name} hit #{job.ttr-1}s timeout"
		end

		job.delete
		log_job_end(name)
	rescue Beanstalk::NotConnected => e
		failed_connection(e)
	rescue SystemExit
		raise
	rescue => e
		log_error exception_message(e)
		job.bury rescue nil
		log_job_end(name, 'failed')
    if error_handler
      if error_handler.arity == 1
        error_handler.call(e)
      else
        error_handler.call(e, name, args)
      end
    end
	end

	def failed_connection(e)
		log_error exception_message(e)
		log_error "*** Failed connection to #{beanstalk_url}"
		log_error "*** Check that beanstalkd is running (or set a different BEANSTALK_URL)"
		exit 1
	end

	def log_job_begin(name, args)
		args_flat = unless args.empty?
			'(' + args.inject([]) do |accum, (key,value)|
				accum << "#{key}=#{value}"
			end.join(' ') + ')'
		else
			''
		end

		log [ "Working", name, args_flat ].join(' ')
		@job_begun = Time.now
	end

	def log_job_end(name, failed=false)
		ellapsed = Time.now - @job_begun
		ms = (ellapsed.to_f * 1000).to_i
		log "Finished #{name} in #{ms}ms #{failed ? ' (failed)' : ''}"
	end

	def log(msg)
		puts msg
	end

	def log_error(msg)
		STDERR.puts msg
	end

	def beanstalk
		@@beanstalk ||= Beanstalk::Pool.new([ beanstalk_host_and_port ])
	end

	def beanstalk_url
		return @@url if defined?(@@url) and @@url
		ENV['BEANSTALK_URL'] || 'beanstalk://localhost/'
	end

	class BadURL < RuntimeError; end

	def beanstalk_host_and_port
		uri = URI.parse(beanstalk_url)
		raise(BadURL, beanstalk_url) if uri.scheme != 'beanstalk'
		return "#{uri.host}:#{uri.port || 11300}"
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

	def error_handler
		@@error_handler
	end

	def clear!
		@@handlers = nil
		@@before_handlers = nil
		@@error_handler = nil
	end
end
