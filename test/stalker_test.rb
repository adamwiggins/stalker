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
		assert_equal val, $result
	end
end
