# Be sure to restart your web server when you modify this file.

#FIXME Necessary hack to avoid the need of downgrading rubygems on rails 2.3.5
# http://stackoverflow.com/questions/5564251/uninitialized-constant-activesupportdependenciesmutex
require 'thread'

# Uncomment below to force Rails into production mode when
# you don't control web/app server and can't set it the proper way
#ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.15' unless defined? RAILS_GEM_VERSION

require 'active_support/all'
ActiveSupport::Deprecation.silenced = true

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

# extra directories for controllers organization
extra_controller_dirs = %w[
  app/controllers/my_profile
  app/controllers/admin
  app/controllers/system
  app/controllers/public
].map {|item| File.join(RAILS_ROOT, item) }

def noosfero_session_secret
  require 'fileutils'
  target_dir = File.join(File.dirname(__FILE__), '/../tmp')
  FileUtils.mkdir_p(target_dir)
  file = File.join(target_dir, 'session.secret')
  if !File.exists?(file)
    secret = (1..128).map { %w[0 1 2 3 4 5 6 7 8 9 a b c d e f][rand(16)] }.join('')
    File.open(file, 'w') do |f|
      f.puts secret
    end
  end
  File.read(file).strip
end

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence those specified here

  # Skip frameworks you're not going to use (only works if using vendor/rails)
  # config.frameworks -= [ :action_web_service, :action_mailer ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )
  config.autoload_paths += %W( #{RAILS_ROOT}/app/sweepers )

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake db:sessions:create')
  config.action_controller.session_store = :active_record_store

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # don't load the sweepers while loading the database
  ignore_rake_commands = %w[
    db:schema:load
    gems:install
    clobber
    noosfero:translations:compile
    makemo
  ]
  if $PROGRAM_NAME =~ /rake$/ && (ignore_rake_commands.include?(ARGV.first))
    $NOOSFERO_LOAD_PLUGINS = false
  else
    $NOOSFERO_LOAD_PLUGINS = true
    config.active_record.observers = :article_sweeper, :role_assignment_sweeper, :friendship_sweeper, :category_sweeper, :block_sweeper
  end
  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc

  # Your secret key for verifying cookie session data integrity.
  # If you change this key, all old sessions will become invalid!
  # Make sure the secret is at least 30 characters and all random,
  # no regular words or you'll be exposed to dictionary attacks.
  config.action_controller.session = {
    :session_key => '_noosfero_session',
    :secret      => noosfero_session_secret(),
  }

  # Adds custom attributes to the Set of allowed html attributes for the #sanitize helper
  config.action_view.sanitized_allowed_attributes = 'align', 'border', 'alt', 'vspace', 'hspace', 'width', 'heigth', 'value', 'type', 'data', 'style', 'target', 'codebase', 'archive', 'classid', 'code', 'flashvars', 'scrolling', 'frameborder', 'controls', 'autoplay'

   # Adds custom tags to the Set of allowed html tags for the #sanitize helper
  config.action_view.sanitized_allowed_tags = 'object', 'embed', 'param', 'table', 'tr', 'th', 'td', 'applet', 'comment', 'iframe', 'audio', 'video', 'source'

  # See Rails::Configuration for more options

  extra_controller_dirs.each do |item|
    $LOAD_PATH << item
    config.controller_paths << item
  end

  require 'rack/cache'
  config.middleware.use Rack::Cache,
    :verbose => true,
    :metastore   => 'memcached://localhost:11211/',
    :entitystore => "file://#{Rails.root}/tmp/rack.cache"

  require 'sass/plugin/rack'
  config.middleware.use Sass::Plugin::Rack
  locations = Dir.glob("#{RAILS_ROOT}/public/designs/themes/*{,/stylesheets}") +
    Dir.glob("#{RAILS_ROOT}/plugins/*/public{,/stylesheets}")
  locations.each do |location|
    Sass::Plugin.add_template_location location, location
  end
end
extra_controller_dirs.each do |item|
  (ActiveSupport.const_defined?('Dependencies') ? ActiveSupport::Dependencies : ::Dependencies).load_paths << item
end

# Add new inflection rules using the following format
# (all these examples are active by default):
# Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end

# Include your application configuration below

ActiveRecord::Base.store_full_sti_class = true

# if you want to override this, do it in config/local.rb !
Noosfero.default_locale = nil

Tag.hierarchical = true

# several local libraries

require_dependency 'noosfero'
require 'sqlite_extension'

# load a local configuration if present, but not under test environment.
if !['test', 'cucumber'].include?(ENV['RAILS_ENV'])
  localconfigfile = File.join(RAILS_ROOT, 'config', 'local.rb')
  if File.exists?(localconfigfile)
    require localconfigfile
  end
end
