# WORKAROUND
require_dependency 'noosfero/plugin/active_record'

class OrdersPlugin::Item < Noosfero::Plugin::ActiveRecord

  # should be Order, but can't reference it here so it would create a cyclic reference
  StatusAccessMap = ActiveSupport::OrderedHash[
    'ordered', :consumer,
    'accepted', :supplier,
    'separated', :supplier,
    'delivered', :supplier,
    'received', :consumer,
  ]
  StatusDataMap = {}; StatusAccessMap.each do |status, access|
    StatusDataMap[status] = "#{access}_#{status}"
  end

  serialize :data

  belongs_to :order, :class_name => 'OrdersPlugin::Order', :touch => true
  belongs_to :sale, :class_name => 'OrdersPlugin::Sale', :foreign_key => :order_id
  belongs_to :purchase, :class_name => 'OrdersPlugin::Purchase', :foreign_key => :order_id

  belongs_to :product

  has_one :profile, :through => :order
  has_one :consumer, :through => :order

  has_many :from_products, :through => :product
  has_many :to_products, :through => :product

  named_scope :ordered, :conditions => ['orders_plugin_orders.status = ?', 'ordered'], :joins => [:order]
  named_scope :for_product, lambda{ |product| {:conditions => {:product_id => product.id}} }

  default_scope :include => [:product]

  validates_presence_of :order
  validates_presence_of :product

  before_save :save_calculated_prices
  before_create :sync_fields

  # utility for other classes
  DefineTotals = proc do
    StatusDataMap.each do |status, data|
      quantity = "quantity_#{data}".to_sym
      price = "price_#{data}".to_sym

      self.send :define_method, "total_#{quantity}" do |items|
        items ||= (self.ordered_items rescue nil) || self.items
        items.collect(&quantity).inject(0){ |sum, q| sum + q.to_f }
      end
      self.send :define_method, "total_#{price}" do |items|
        items ||= (self.ordered_items rescue nil) || self.items
        items.collect(&price).inject(0){ |sum, p| sum + p.to_f }
      end

      has_number_with_locale "total_#{quantity}"
      has_currency "total_#{price}"
    end
  end

  extend CurrencyHelper::ClassMethods
  has_currency :price
  StatusDataMap.each do |status, data|
    quantity = "quantity_#{data}"
    price = "price_#{data}"

    has_number_with_locale quantity
    has_currency price

    validates_numericality_of quantity, :allow_nil => true
    validates_numericality_of price, :allow_nil => true
  end

  def self.products_by_suppliers items
    items.group_by(&:supplier).map do |supplier, items|
      products = []
      total_price_consumer_ordered = 0

      items.group_by(&:product).each do |product, items|
        products << product
        product.ordered_items = items
        total_price_consumer_ordered += product.total_price_consumer_ordered items
      end

      [supplier, products, total_price_consumer_ordered]
    end
  end

  # Attributes cached from product
  def name
    self['name'] || (self.product.name rescue nil)
  end
  def price
    self['price'] || (self.product.price rescue nil)
  end
  def unit
    self.product.unit
  end
  def supplier
    self.product.supplier rescue self.order.profile.self_supplier
  end

  def status
    self.order.status
  end

  StatusDataMap.each do |status, data|
    quantity = "quantity_#{data}".to_sym
    price = "price_#{data}".to_sym

    self.send :define_method, "calculated_#{price}" do |items|
      self.price * self.send(quantity) rescue nil
    end
  end

  def quantity_price_data actor_name
    data = ActiveSupport::OrderedHash.new
    statuses = OrdersPlugin::Order::Statuses

    current = statuses.index(self.order.status) || 0
    next_status = self.order.next_status actor_name
    next_index = statuses.index(next_status) || current + 1
    goto_next = actor_name == StatusAccessMap[next_status]

    # Fetch data
    statuses.each_with_index do |status, i|
      data_field = StatusDataMap[status]
      access = StatusAccessMap[status]

      status_data = data[status] = {
        :flags => {},
        :field => data_field,
        :access => access,
      }

      if self.send("quantity_#{data_field}").present?
        status_data[:quantity] = self.send "quantity_#{data_field}_localized"
        status_data[:price] = self.send "price_#{data_field}_as_currency_number"
        status_data[:flags][:filled] = true
      else
        status_data[:flags][:empty] = true
      end

      if i == current
        status_data[:flags][:current] = true
      elsif i == next_index and goto_next
        status_data[:flags][:admin] = true
      end

      break if (if goto_next then i == next_index else i < next_index end)
    end

    # Set flags according to past/future data
    # Present flags are used as classes
    data.each_with_index do |(status, status_data), i|
      prev_status_data = data[statuses[i-1]] unless i.zero?
      next_status_data = data[statuses[i+1]]

      if prev_status_data
        if status_data[:quantity] == prev_status_data[:quantity]
          status_data[:flags][:not_modified] = true
        elsif status_data[:flags][:empty]
          # fill with previous status data
          status_data[:quantity] = prev_status_data[:quantity]
          status_data[:price] = prev_status_data[:price]
          status_data[:flags][:filled] = status_data[:flags].delete :empty
          status_data[:flags][:not_modified] = true
        end
      end

      if next_status_data
        if next_status_data[:flags][:filled] and status_data[:quantity] != next_status_data[:quantity]
          status_data[:flags][:overwritten] = true
        end
      end
    end

    # Set access
    data.each_with_index do |(status, status_data), i|
      status_data[:flags][:editable] = true if status_data[:access] == actor_name and (status_data[:flags][:admin] or self.order.open?)
    end

    data
  end

  protected

  def save_calculated_prices
    StatusDataMap.each do |status, data|
      price = "price_#{data}".to_sym
      self.send "#{price}=", self.send("calculated_#{price}")
    end
  end

  def sync_fields
    self.name = self.product.name
    self.price = self.product.price
  end

end
