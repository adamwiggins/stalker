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

  def with_an_error_handler
    Stalker.error do |e, job_name, args|
      $handled = e.class
      $job_name = job_name
      $job_args = args
    end
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
    with_an_error_handler
    Stalker.job('my.job') { |args| fail }
    Stalker.enqueue('my.job', :foo => 123)
    Stalker.prep
    Stalker.work_one_job
    assert $handled
    assert_equal 'my.job', $job_name
    assert_equal({'foo' => 123}, $job_args)
  end

  test "should be compatible with legacy error handlers" do
    exception = StandardError.new("Oh my, the job has failed!")
    Stalker.error { |e| $handled = e }
    Stalker.job('my.job') { |args| raise exception }
    Stalker.enqueue('my.job', :foo => 123)
    Stalker.prep
    Stalker.work_one_job
    assert_equal exception, $handled
  end

  test "continue working when error handler not defined" do
    Stalker.job('my.job') { fail }
    Stalker.enqueue('my.job')
    Stalker.prep
    Stalker.work_one_job
    assert_equal false, $handled
  end

  test "exception raised one second before beanstalk ttr reached" do
    with_an_error_handler
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
    with_an_error_handler
    Stalker.before { |name| fail }
    Stalker.job('my.job') {  }
    Stalker.enqueue('my.job', :foo => 123)
    Stalker.prep
    Stalker.work_one_job
    assert $handled
    assert_equal 'my.job', $job_name
    assert_equal({'foo' => 123}, $job_args)
  end
  
  test "parse BEANSTALK_URL" do
    ENV['BEANSTALK_URL'] = "beanstalk://localhost:12300"
    assert_equal Stalker.beanstalk_addresses, ["localhost:12300"]
    ENV['BEANSTALK_URL'] = "beanstalk://localhost:12300/, beanstalk://localhost:12301/"
    assert_equal Stalker.beanstalk_addresses, ["localhost:12300","localhost:12301"]
    ENV['BEANSTALK_URL'] = "beanstalk://localhost:12300   beanstalk://localhost:12301"
    assert_equal Stalker.beanstalk_addresses, ["localhost:12300","localhost:12301"]
    ENV['BEANSTALK_URL'] = "beanstalk://localhost:12300, http://localhost:12301"
    assert_raise Stalker::BadURL do
      Stalker.beanstalk_addresses 
    end
  end

end
