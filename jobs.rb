$LOAD_PATH.unshift 'lib'
require 'stalker'

include Stalker

priority :high do
	job 'send.email' do |args|
		puts "Sending email: #{args.inspect}"
	end

	job 'transform.image' do |args|
		puts "Image transform"
	end
end

priority :low do
	job 'cleanup.strays' do |args|
		puts "Cleaning up"
	end
end
