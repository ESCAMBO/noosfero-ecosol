require File.dirname(__FILE__) + '/../test_helper'

class TaskTest < Test::Unit::TestCase

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    TaskMailer.stubs(:deliver_task_created)
  end

  def test_relationship_with_requestor
    t = Task.create
    assert_raise ActiveRecord::AssociationTypeMismatch do
      t.requestor = 1
    end
    assert_nothing_raised do
      t.requestor = Person.new
    end
  end

  def test_relationship_with_target
    t = Task.create
    assert_raise ActiveRecord::AssociationTypeMismatch do
      t.target = 1
    end
    assert_nothing_raised do
      t.target = Profile.new
    end
  end

  def test_should_call_perform_in_finish
    TaskMailer.expects(:deliver_task_finished)
    t = Task.create
    t.requestor = sample_user
    t.expects(:perform)
    t.finish
    assert_equal Task::Status::FINISHED, t.status
  end

  def test_should_have_cancelled_status_after_cancel
    TaskMailer.expects(:deliver_task_cancelled)
    t = Task.create
    t.requestor = sample_user
    t.cancel
    assert_equal Task::Status::CANCELLED, t.status
  end

  def test_should_start_with_active_status
    t = Task.create
    assert_equal Task::Status::ACTIVE, t.status
  end

  def test_should_notify_finish
    t = Task.create
    t.requestor = sample_user

    TaskMailer.expects(:deliver_task_finished).with(t)

    t.finish
  end

  def test_should_notify_cancel
    t = Task.create
    t.requestor = sample_user

    TaskMailer.expects(:deliver_task_cancelled).with(t)

    t.cancel
  end

  def test_should_not_notify_when_perform_fails
    count = Task.count

    t = Task.create
    class << t
      def perform
        raise RuntimeError
      end
    end

    t.expects(:notify_requestor).never
    assert_raise RuntimeError do
      t.finish
    end
  end

  should 'provide a description method' do
    assert_kind_of String, Task.new.description
  end

  should 'notify just after the task is created' do
    task = Task.new
    task.requestor = sample_user

    TaskMailer.expects(:deliver_task_created).with(task)
    task.save!
  end

  should 'generate a random code before validation' do
    Task.expects(:generate_code)
    Task.new.valid?
  end

  should 'make sure that codes are unique' do
    task1 = Task.create!
    task2 = Task.new(:code => task1.code)

    assert !task2.valid?
    assert task2.errors.invalid?(:code)
  end

  should 'generate a code with chars from a-z and 0-9' do
    code = Task.generate_code
    assert(code =~ /^[a-z0-9]+$/)
    assert_equal 36, code.size
  end

  should 'find only in active tasks' do
    task = Task.new
    task.requestor = sample_user
    task.save!
    
    task.cancel

    assert_nil Task.find_by_code(task.code)
  end

  should 'be able to find active tasks ' do
    task = Task.new
    task.requestor = sample_user
    task.save!

    assert_not_nil Task.find_by_code(task.code)
  end

  should 'not send notification to target when target_notification_message is nil (as in Task base class)' do
    task = Task.new
    TaskMailer.expects(:deliver_target_notification).never
    task.save!
    assert_nil task.target_notification_message
  end

  should 'send notification to target just after task creation' do
    task = Task.new
    task.stubs(:target_notification_message).returns('some non nil message to be sent to target')
    TaskMailer.expects(:deliver_target_notification).once
    task.save!
  end

  should 'be able to list pending tasks for a given target' do
    target = sample_user 

    assert_equal [], Task.pending_for(target)

    task = Task.new
    task.target = target
    task.save!

    assert_equal [task], Task.pending_for(target)
  end

  should 'be able to pass extra conditions for getting pending tasks' do
    target = sample_user

    task = Task.new
    task.target = target
    task.save!

    assert_equal [], Task.pending_for(target, :id => -1)
  end

  should 'be able to list processed tasks' do
    target = sample_user

    task = Task.new
    task.target = target
    task.finish

    # this one shouldn't be listed as processed, since it was not
    task2 = Task.new
    task2.target = target
    target.save!

    assert_equal [task], Task.processed_for(target)
  end

  should 'be able to pass optional parameters for getting processed tasks' do
    target = sample_user

    task = Task.new
    task.target = target
    task.finish

    assert_equal [], Task.processed_for(target, :id => -1)
  end

  protected

  def sample_user
    User.create(:login => 'testfindinactivetask', :password => 'test', :password_confirmation => 'test', :email => 'testfindinactivetask@localhost.localdomain').person
  end

end
