# frozen_string_literal: true

class AntennasController < ApplicationController
  layout 'admin'

  before_action :authenticate_user!
  before_action :set_antenna, only: [:edit, :update, :destroy]
  before_action :set_lists, only: [:new, :edit]
  before_action :set_body_classes
  before_action :set_cache_headers

  def index
    @antennas = current_account.antennas.includes(:antenna_domains).includes(:antenna_tags).includes(:antenna_accounts)
  end

  def new
    @antenna = current_account.antennas.build
    @antenna.antenna_domains.build
    @antenna.antenna_tags.build
    @antenna.antenna_accounts.build
  end

  def edit; end

  def create
    @antenna = current_account.antennas.build(thin_resource_params)

    saved = @antenna.save
    saved = @antenna.update(resource_params) if saved

    if saved
      redirect_to antennas_path
    else
      render action: :new
    end
  end

  def update
    if @antenna.update(resource_params)
      redirect_to antennas_path
    else
      render action: :edit
    end
  end

  def destroy
    @antenna.destroy
    redirect_to antennas_path
  end

  private

  def set_antenna
    @antenna = current_account.antennas.find(params[:id])
  end

  def set_lists
    @lists = current_account.owned_lists
  end

  def resource_params
    params.require(:antenna).permit(:title, :list, :available, :insert_feeds, :stl, :expires_in, :with_media_only, :ignore_reblog, :keywords_raw, :exclude_keywords_raw, :domains_raw, :exclude_domains_raw, :accounts_raw, :exclude_accounts_raw, :tags_raw, :exclude_tags_raw)
  end

  def thin_resource_params
    params.require(:antenna).permit(:title, :list)
  end

  def set_body_classes
    @body_classes = 'admin'
  end

  def set_cache_headers
    response.cache_control.replace(private: true, no_store: true)
  end
end
