class HomeController < ApplicationController
  skip_before_action :require_login!, only: [ :index ]

  def index
    redirect_to organizations_path if current_user
  end
end
