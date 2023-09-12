# frozen_string_literal: true

class DeliveryEmojiReactionWorker
  include Sidekiq::Worker
  include Redisable
  include Lockable
  include AccountScope

  def perform(payload_json, emoji_reaction_id, _status_id, _my_account_id = nil)
    emoji_reaction = EmojiReaction.find(emoji_reaction_id)
    status = emoji_reaction&.status

    if status.present?
      return if status.account.excluded_from_timeline_domains.include?(emoji_reaction.account.domain)

      scope_status(status).includes(:user).find_each do |account|
        next unless (account.user.nil? || (!account.user&.setting_stop_emoji_reaction_streaming && !account.user&.setting_enable_emoji_reaction)) && redis.exists?("subscribed:timeline:#{account.id}")
        next if account.excluded_from_timeline_domains.include?(emoji_reaction.account.domain)

        redis.publish("timeline:#{account.id}", payload_json)
      end
    end

    true
  rescue ActiveRecord::RecordNotFound
    true
  end
end
