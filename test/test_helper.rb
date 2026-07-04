ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require_relative "support/fake_hcb_client"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Stubs Hcb::OrganizationMembers.role_for, which now returns a Membership
    # (role + resolved organization id) rather than a bare role string.
    def stub_membership(role, organization_id: "org_1", &block)
      membership = Hcb::OrganizationMembers::Membership.new(organization_id: organization_id, role: role)
      Hcb::OrganizationMembers.stub :role_for, membership, &block
    end
  end
end
