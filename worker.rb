$LOAD_PATH.unshift 'lib'
require 'stalker'

include Stalker

job 'send.email' do |args|
	puts "Sending email: #{args.inspect}"
end

run

