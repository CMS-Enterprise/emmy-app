require "capybara/selenium/driver"

module E2e
  # Capybara 3.40's Chrome reset sends Storage.clearDataForOrigin with origin "*",
  # which Chrome 158 rejects. Use Capybara's standard reset to clear cookies and
  # both storage types before navigating away, retaining its alert handling.
  # Remove this override when Capybara's Chrome reset supports current Chrome.
  module ChromeSessionReset
    def reset!
      return unless @browser

      switch_to_window(window_handles.first)
      window_handles.drop(1).each { |handle| close_window(handle) }
      Capybara::Selenium::Driver.instance_method(:reset!).bind_call(self)
    end
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(E2e::ChromeSessionReset)
