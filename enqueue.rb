$LOAD_PATH.unshift 'lib'
require 'stalker'

require 'jobs'

Stalker.enqueue('send.email', :email => 'hello@example.com')
Stalker.enqueue('cleanup.strays')

