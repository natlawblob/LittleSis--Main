# frozen_string_literal: true

class DashboardBulletinsController < ApplicationController
  before_action :authenticate_user!
  before_action :admins_only

  def new
  end

  def create
    DashboardBulletin.create!(bulletin_params)
    redirect_to home_dashboard_path
  end

  def edit
    @bulletin = DashboardBulletin.find(params.require(:id))
  end

  def update
    DashboardBulletin
      .find(params.require(:id))
      .update!(bulletin_params)

    redirect_to home_dashboard_path
  end

  private

  def bulletin_params
    params.require(:dashboard_bulletin).permit(:title, :markdown).to_h
  end
end
