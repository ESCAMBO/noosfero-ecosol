class ExchangePlugin::ProfileExchange < Noosfero::Plugin::ActiveRecord

  belongs_to :profile
  belongs_to :exchange, :class_name => "ExchangePlugin::Exchange"

  validates_presence_of :profile
  validates_presence_of :exchange

  def the_other
    self.class.first(:conditions => {:exchange_id => self.exchange_id, :profile_id => self.profile_id}).profile
  end

end
