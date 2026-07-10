class Api::CommentsController < ApplicationController
  include OrganizationScoped

  # Comments are fetched on demand (when the detail modal for a transaction
  # is opened) rather than bundled into the bulk transaction list -- HCB's
  # comments endpoint is per-transaction, so pulling it in for every row up
  # front would mean one extra API call per transaction against the shared
  # rate limit.
  def index
    data = hcb_client.comments(params[:id])

    render json: {
      comments: data.map do |c|
        {
          user_name: c.dig("user", "name") || "",
          content: c["content"] || "",
          file_url: c["file"],
          admin_only: !!c["admin_only"]
        }
      end
    }
  end
end
