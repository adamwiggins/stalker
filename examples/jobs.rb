$LOAD_PATH.unshift '../lib'
require 'stalker'

include Stalker

job 'send.email' do |args|
	log "Sending email to #{args['email']}"
end

job 'transform.image' do |args|
	log "Image transform"
end

job 'cleanup.strays' do |args|
	log "Cleaning up"
end
