# frozen_string_literal: true

# == Schema Information
#
# Table name: emoji_reactions
#
#  id              :bigint(8)        not null, primary key
#  account_id      :bigint(8)        not null
#  status_id       :bigint(8)        not null
#  name            :string           default(""), not null
#  custom_emoji_id :bigint(8)
#  uri             :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class EmojiReaction < ApplicationRecord
  include Paginable

  EMOJI_REACTION_LIMIT = 32767
  EMOJI_REACTION_PER_ACCOUNT_LIMIT = 3

  update_index('statuses', :status)

  belongs_to :account,       inverse_of: :emoji_reactions
  belongs_to :status,        inverse_of: :emoji_reactions
  belongs_to :custom_emoji,  optional: true

  has_one :notification, as: :activity, dependent: :destroy

  after_create :refresh_cache
  after_destroy :refresh_cache
  after_destroy :invalidate_cleanup_info

  private

  def refresh_cache
    status&.refresh_emoji_reactions_grouped_by_name!
  end

  def invalidate_cleanup_info
    return unless status&.account_id == account_id && account.local?

    account.statuses_cleanup_policy&.invalidate_last_inspected(status, :unfav)
  end

  def paginate_by_max_id(limit, max_id = nil, since_id = nil)
    query = order(arel_table[:id].desc).limit(limit)
    query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
    query = query.where(arel_table[:id].gt(since_id)) if since_id.present?
    query
  end
end