module OrganizationScoped
  extend ActiveSupport::Concern

  included do
    before_action :load_organization_role!
    helper_method :organization_id
  end

  def organization_id = params[:organization_id]

  private

  def load_organization_role!
    @current_role = Hcb::OrganizationMembers.role_for(
      client: hcb_client, organization_id: organization_id, hcb_user_id: current_user.hcb_user_id
    )
    head :forbidden unless @current_role
  end

  def require_matcher_role!
    return if %w[member manager].include?(@current_role)

    render json: { error: "Only members or managers can do that." }, status: :forbidden
  end
end
