require 'simplecov'
SimpleCov.start
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'metapage'
require 'webmock'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = File.join(File.dirname(__FILE__), 'fixtures/vcr_cassettes')
  config.hook_into :webmock # or :fakeweb
  config.default_cassette_options = { record: :new_episodes }
  config.configure_rspec_metadata!
end