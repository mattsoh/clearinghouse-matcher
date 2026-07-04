module OrganizationScoped
  extend ActiveSupport::Concern

  included do
    before_action :load_organization_role!
    helper_method :organization_id, :organization_slug
  end

  def organization_id = @organization_id

  # Falls back to the immutable id when HCB hasn't given the org a slug, so
  # links always have something valid to route on.
  def organization_slug = @organization_slug || @organization_id

  private

  # params[:organization_id] may be the org's immutable id or its (mutable,
  # renameable) slug -- HCB's API resolves either. Everything past this
  # point uses the immutable id for persistence/lookups, so a later slug
  # rename can't orphan locally-persisted matches/cutoffs keyed on it. The
  # slug is kept separately, only for generating nicer-looking links.
  def load_organization_role!
    membership = Hcb::OrganizationMembers.role_for(
      client: hcb_client, organization_id: params[:organization_id], hcb_user_id: current_user.hcb_user_id
    )
    return head :forbidden unless membership.role

    @organization_id = membership.organization_id
    @organization_slug = membership.organization_slug
    @current_role = membership.role
  end

  def require_matcher_role!
    return if %w[member manager].include?(@current_role)

    render json: { error: "Only members or managers can do that." }, status: :forbidden
  end

  # For actions consequential enough to affect other users' work at once
  # (e.g. moving the cutoff can cascade-undo matches other people created).
  def require_manager_role!
    return if @current_role == "manager"

    render json: { error: "Only managers can do that." }, status: :forbidden
  end
end
