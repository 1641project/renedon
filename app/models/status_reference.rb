# frozen_string_literal: true

# == Schema Information
#
# Table name: status_references
#
#  id               :bigint(8)        not null, primary key
#  status_id        :bigint(8)        not null
#  target_status_id :bigint(8)        not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class StatusReference < ApplicationRecord
  belongs_to :status
  belongs_to :target_status, class_name: 'Status'

  has_one :notification, as: :activity, dependent: :destroy

  validate :validate_status_visibilities

  def validate_status_visibilities
    raise Mastodon::ValidationError, I18n.t('status_references.errors.invalid_status_visibilities') if [:public, :public_unlisted, :unlisted, :login].exclude?(target_status.visibility.to_sym)
  end
end
