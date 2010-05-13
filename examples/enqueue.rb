$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
require 'stalker'

Stalker.enqueue('send.email', :email => 'hello@example.com')
Stalker.enqueue('cleanup.strays')
