require 'memcached'
Stalker.cache = Memcached.new

job 'send.email' do |args|
	log "Sending email to #{args['email']}"
end

job 'transform.image' do |args|
	log "Image transform"
end

job 'cleanup.strays', :lock_for => 30 do |args|
	log "Cleaning up"
end
