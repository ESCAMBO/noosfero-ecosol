class DistributionPlugin::Node < Noosfero::Plugin::ActiveRecord
  belongs_to :profile
end

class MoveDistributionPluginStuffToConsumersCoopPlugin < ActiveRecord::Migration
  def self.up
    DistributionPlugin::Node.all.each do |node|
      profile = node.profile
      next if profile.nil?

      # declared at suppliers_plugin
      profile.margin_percentage = node.margin_percentage

      profile.consumers_coop_settings.enabled = node.role == 'collective'
      %w[name_abbreviation header_type header_fg_color header_bg_color].each do |sett|
        profile.consumers_coop_settings.send "#{sett}=", node.send(sett)
      end

      profile.save
    end

    drop_table :distribution_plugin_nodes
    remove_column :distribution_plugin_sessions, :margin_fixed
  end

  def self.down
    say "this migration can't be reverted"
  end
end
