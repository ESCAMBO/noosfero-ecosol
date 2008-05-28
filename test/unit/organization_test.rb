require File.dirname(__FILE__) + '/../test_helper'

class OrganizationTest < Test::Unit::TestCase
  fixtures :profiles

  def create_create_enterprise(org)
    region = Region.create!(:name => 'some region', :environment => Environment.default)
    region.validators << org

    requestor = create_user('testreq').person

    data = {
      :name => 'My new enterprise',
      :identifier => 'mynewenterprise',
      :address => 'satan street, 666',
      :contact_phone => '1298372198',
      :contact_person => 'random joe',
      :legal_form => 'cooperative',
      :economic_activity => 'free software',
      :region_id => region.id,
      :requestor => requestor,
      :target => org,
    }
    CreateEnterprise.create!(data)
  end


  should 'not reference organization info' do
    org = Organization.new
    assert_raise NoMethodError do
      org.organization_info
    end
  end

  should 'reference region' do
    org = Organization.new
    assert_raise ActiveRecord::AssociationTypeMismatch do
      org.region = 1
    end
    assert_nothing_raised do
      org.region = Region.new
    end
  end

  should 'reference validation info' do
    org = Organization.new
    assert_raise ActiveRecord::AssociationTypeMismatch do
      org.validation_info = 1
    end
    assert_nothing_raised do
      org.validation_info = ValidationInfo.new
    end
  end

  should 'provide validation methodology' do
    org = Organization.new
    assert_nil org.validation_methodology

    info = ValidationInfo.new
    info.expects(:validation_methodology).returns('something')
    org.validation_info = info
    assert_equal 'something', org.validation_methodology
  end

  should 'provide validation restrictions' do
    org = Organization.new
    assert_nil org.validation_restrictions

    info = ValidationInfo.new
    info.expects(:restrictions).returns('something')
    org.validation_info = info
    assert_equal 'something', org.validation_restrictions
  end

  should 'have contact_email' do
    org = Organization.new
    assert_respond_to org, :contact_email
  end

  should 'list pending enterprise validations' do
    org = Organization.new
    assert_kind_of Array, org.pending_validations
  end

  should 'be able to find a pending validation by its code' do
    org = Organization.create!(:name => 'test org', :identifier => 'testorg')

    validation = create_create_enterprise(org)

    ok('should find pending validation by code') { validation == org.find_pending_validation(validation.code) }
  end

  should 'return nil when finding for an unexisting pending validation' do
    org = Organization.new
    assert_nil org.find_pending_validation('xxxxxxxxxxxxxxxxxxx')
  end

  should 'be able to find already processed validations' do
    org = Organization.new
    assert_kind_of Array, org.processed_validations
  end

  should 'be able to find an already processed validation by its code' do
    org = Organization.create!(:name => 'test org', :identifier => 'testorg')
    validation = create_create_enterprise(org)
    validation.finish

    ok('should find processed validation by code') { validation == org.find_processed_validation(validation.code) }
  end

  should 'have boxes and blocks upon creation' do
    profile = Organization.create!(:name => 'test org', :identifier => 'testorg')

    assert profile.boxes.size > 0
    assert profile.blocks.size > 0
  end

  should 'have members' do
    assert_equal true, Organization.new.has_members?
  end

  should 'update contact_person' do
    org = Organization.create!(:name => 'test org', :identifier => 'testorg')
    assert_nil org.contact_person
    org.contact_person = 'person'
    assert_not_nil org.contact_person
  end

  should 'numericality year' do
    count = Organization.count

    org = Organization.new
    org.foundation_year = 'xxxx'
    org.valid?
    assert org.errors.invalid?(:foundation_year)

    org.foundation_year = 20.07
    org.valid?
    assert org.errors.invalid?(:foundation_year)
    
    org.foundation_year = 2007
    org.valid?
    assert ! org.errors.invalid?(:foundation_year)
  end

  should 'provide needed information in summary' do
    organization = Organization.new

    organization.acronym = 'organization acronym'
    organization.foundation_year = '2007'
    organization.contact_email = 'my contact email'

    summary = organization.summary
    assert(summary.any? { |line| line[1] == 'organization acronym' })
    assert(summary.any? { |line| line[1] == '2007' })
    assert(summary.any? { |line| line[1] == 'my contact email' })
  end

  should 'has closed' do
    org = Organization.new
    assert_respond_to org, :closed
    assert_respond_to org, :closed?
  end
  
end
