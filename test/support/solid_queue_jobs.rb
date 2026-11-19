# Queues the jobs of a block in Solid Queue, as the servers do, instead of in
# the test adapter, and runs them the way its worker does. Solid Queue keeps
# the arguments of a job as JSON in the database; an argument JSON cannot
# carry, such as binary data, fails only there.
module SolidQueueJobs

  def enqueue_in_solid_queue
    test_adapter = ActiveJob::Base._test_adapter
    ActiveJob::Base.enable_test_adapter(ActiveJob::QueueAdapters::SolidQueueAdapter.new)
    yield
  ensure
    ActiveJob::Base.enable_test_adapter(test_adapter)
  end

  def work_off_solid_queue
    SolidQueue::Job.find_each { ActiveJob::Base.execute(it.arguments) }
  end

end
