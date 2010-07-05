require File.dirname(__FILE__) + '/../lib/stalker'
require 'contest'
require 'mocha'

module Stalker
	def log(msg)
	end
end

class StalkerTest < Test::Unit::TestCase
	setup do
		Stalker.clear!
		$result = -1
	end

	test "enqueue and work a job" do
		val = rand(999999)
		Stalker.job('my.job') { |args| $result = args['val'] }
		Stalker.enqueue('my.job', :val => val)
		Stalker.prep
		Stalker.work_one_job
		assert_equal $result, val
	end

	test "use memcache lock" do
		require 'memcached'
		Stalker.cache = Memcached.new

		Stalker.job('lock.job', :lock_for => 1) { |args| $result = 999 }
		3.times { Stalker.enqueue('lock.job') }
		Stalker.prep

		$result = -1
		Stalker.work_one_job
		assert_equal 999, $result

		$result = -1
		Stalker.work_one_job
		assert_equal -1, $result

		sleep 1.1
		$result = -1
		Stalker.work_one_job
		assert_equal 999, $result
	end
end
