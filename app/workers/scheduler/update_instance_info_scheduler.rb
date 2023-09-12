# frozen_string_literal: true

class Scheduler::UpdateInstanceInfoScheduler
  include Sidekiq::Worker

  sidekiq_options retry: 0, lock: :until_executed, lock_ttl: 1.day.to_i

  def perform
    Instance.select(:domain).reorder(nil).find_in_batches do |instances|
      ActivityPub::FetchInstanceInfoWorker.push_bulk(instances) do |instance|
        [instance.domain]
      end
    end
  end
end
