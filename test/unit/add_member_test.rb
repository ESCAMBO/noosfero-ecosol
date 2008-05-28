require File.dirname(__FILE__) + '/../test_helper'

class AddMemberTest < ActiveSupport::TestCase

  should 'be a task' do
    ok { AddMember.new.kind_of?(Task) }
  end

  should 'actually add memberships when confirmed' do
    p = create_user('testuser1').person
    c = Community.create!(:name => 'closed community', :closed => true)
    task = AddMember.create!(:person => p, :community => c)
    assert_difference c, :members, [p] do
      task.finish
      c.reload
    end
  end

  should 'require requestor' do
    task = AddMember.new
    task.valid?

    ok('must not validate with empty requestor') { task.errors.invalid?(:requestor_id) }

    task.requestor = Person.new
    task.valid?
    ok('must validate when requestor is given') { task.errors.invalid?(:requestor_id)}
  end

  should 'require target' do
    task = AddMember.new
    task.valid?

    ok('must not validate with empty target') { task.errors.invalid?(:target_id) }

    task.target = Person.new
    task.valid?
    ok('must validate when target is given') { task.errors.invalid?(:target_id)}
  end

  should 'not send e-mails' do
    p = create_user('testuser1').person
    c = Community.create!(:name => 'closed community', :closed => true)

    TaskMailer.expects(:deliver_task_finished).never
    TaskMailer.expects(:deliver_task_created).never

    task = AddMember.create!(:person => p, :community => c)
    task.finish
  end

  should 'provide proper description' do
    p = create_user('testuser1').person
    c = Community.create!(:name => 'closed community', :closed => true)

    TaskMailer.expects(:deliver_task_finished).never
    TaskMailer.expects(:deliver_task_created).never

    task = AddMember.create!(:person => p, :community => c)

    assert_equal 'testuser1 wants to be a member', task.description
  end

  should 'has community alias to target' do
    t = AddMember.new
    assert_same t.target, t.community
  end

end
