require "capybara/rails"
require "capybara/rspec"
require "webdrivers/chromedriver"

Webdrivers.cache_time = 86_400

Capybara.default_max_wait_time = 10

# Disable internet connection with Webmock
# allow browser websites, so that "webdrivers" can access their binaries
# see <https://github.com/titusfortner/webdrivers/wiki/Using-with-VCR-or-WebMock>
allowed_sites = [
  "https://chromedriver.storage.googleapis.com",
  "https://github.com/mozilla/geckodriver/releases",
  "https://selenium-release.storage.googleapis.com",
  "https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver",
  "api.knapsackpro.com",
] + Webdrivers::Common.subclasses.map(&:base_url).host

WebMock.disable_net_connect!(allow_localhost: true, allow: allowed_sites.uniq)

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    # stub_request(:get, /^https:\/\/chromedriver.storage.googleapis.com.*$/).
    #   to_return(status: 200, body: "", headers: {})

    if ENV["SELENIUM_URL"].present?
      # Support use of remote chrome testing.
      Capybara.server_host = ENV.fetch("CAPYBARA_SERVER_HOST") { "0.0.0.0" }
      ip = Socket.ip_address_list.detect(&:ipv4_private?).ip_address
      host! URI::HTTP.build(host: ip, port: Capybara.server_port).to_s

      driven_by :selenium, using: :chrome, screen_size: [1400, 2000], options: { url: ENV["SELENIUM_URL"] }
    else
      # options from https://github.com/teamcapybara/capybara#selenium
      chrome = ENV["HEADLESS"] == "false" ? :selenium_chrome : :selenium_chrome_headless
      driven_by chrome
    end
  end
end

# adapted from <https://medium.com/doctolib-engineering/hunting-flaky-tests-2-waiting-for-ajax-bd76d79d9ee9>
def wait_for_javascript
  max_time = Capybara::Helpers.monotonic_time + Capybara.default_max_wait_time
  finished = false

  while Capybara::Helpers.monotonic_time < max_time
    finished = page.evaluate_script("typeof initializeBaseApp") != "undefined"

    break if finished

    sleep 0.1
  end

  raise "wait_for_javascript timeout" unless finished
end
