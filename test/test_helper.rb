ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Replaces a singleton method for the duration of the block.
    def with_stub(object, method_name, implementation)
      original = object.method(method_name)
      object.define_singleton_method(method_name, &implementation)
      yield
    ensure
      object.define_singleton_method(method_name, original)
    end
  end
end
