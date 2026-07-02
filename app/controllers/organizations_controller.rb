class OrganizationsController < ApplicationController
  def index
    @organizations = Rails.cache.fetch("hcb:user:#{current_user.id}:organizations:v1", expires_in: 5.minutes) do
      response = hcb_client.organizations
      response.is_a?(Hash) ? (response["data"] || []) : response
    end
  end
end
