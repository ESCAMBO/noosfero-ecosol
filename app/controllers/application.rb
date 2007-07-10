# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base

  before_filter :detect_stuff_by_domain
  attr_reader :virtual_community

  #TODO To diplay the content we need a variable called '@boxes'. 
  #This variable is a set of boxes belongs to a owner
  #We have to see a better way to do that
  before_filter :load_boxes
  def load_boxes
    if Profile.exists?(1)
      owner = Profile.find(1) 
      @boxes = owner.boxes 
    end
  end

  before_filter :load_template
  def load_template
    if Profile.exists?(1)
      owner = Profile.find(1) 
    end
    @chosen_template = owner.nil? ? "default" : owner.template
  end

  protected

  def detect_stuff_by_domain
    @domain = Domain.find_by_name(request.host)
    if @domain.nil?
      @virtual_community = VirtualCommunity.default
    else
      @virtual_community = @domain.virtual_community
      @profile = @domain.profile
    end
  end

  def self.acts_as_admin_controller
    before_filter :load_admin_controller
  end
  def load_admin_controller
    # TODO: check access control
  end

end
