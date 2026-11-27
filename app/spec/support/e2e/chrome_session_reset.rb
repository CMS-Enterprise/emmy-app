require "capybara/selenium/driver"

module E2e
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
