require File.expand_path('../../lib/stalker', __FILE__)
require 'contest'
require 'mocha'

module Stalker
	def log(msg); end
	def log_error(msg); end
end

class StalkerTest < Test::Unit::TestCase
	setup do
		Stalker.clear!
		$result = -1
		$handled = false
	end

	test "enqueue and work a job" do
		val = rand(999999)
		Stalker.job('my.job') { |args| $result = args['val'] }
		Stalker.enqueue('my.job', :val => val)
		Stalker.prep
		Stalker.work_one_job
		assert_equal val, $result
	end

	test "invoke error handler when defined" do
		Stalker.error { |e| $handled = true }
		Stalker.job('my.job') { fail }
		Stalker.enqueue('my.job')
		Stalker.prep
		Stalker.work_one_job
		assert_equal true, $handled
	end

	test "continue working when error handler not defined" do
		Stalker.job('my.job') { fail }
		Stalker.enqueue('my.job')
		Stalker.prep
		Stalker.work_one_job
		assert_equal false, $handled
	end

	test "exception raised one second before beanstalk ttr reached" do
		Stalker.error { |e| $handled = e.class }
		Stalker.job('my.job') { sleep(3); $handled = "didn't time out" }
		Stalker.enqueue('my.job', {}, :ttr => 2)
		Stalker.prep
		Stalker.work_one_job
		assert_equal Stalker::JobTimeout, $handled
	end

	test "before filter gets run first" do
		Stalker.before { |name| $flag = "i_was_here" }
		Stalker.job('my.job') { |args| $handled = ($flag == 'i_was_here') }
		Stalker.enqueue('my.job')
		Stalker.prep
		Stalker.work_one_job
		assert_equal true, $handled
	end

	test "before filter passes the name of the job" do
		Stalker.before { |name| $jobname = name }
		Stalker.job('my.job') { true }
		Stalker.enqueue('my.job')
		Stalker.prep
		Stalker.work_one_job
		assert_equal 'my.job', $jobname
	end

	test "before filter can pass an instance var" do
		Stalker.before { |name| @foo = "hello" }
		Stalker.job('my.job') { |args| $handled = (@foo == "hello") }
		Stalker.enqueue('my.job')
		Stalker.prep
		Stalker.work_one_job
		assert_equal true, $handled
	end

	test "before filter invokes error handler when defined" do
		Stalker.error { |e| $handled = true }
		Stalker.before { |name| fail }
		Stalker.job('my.job') {	}
		Stalker.enqueue('my.job')
		Stalker.prep
		Stalker.work_one_job
		assert_equal true, $handled
	end

end
