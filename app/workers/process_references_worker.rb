# frozen_string_literal: true

class ProcessReferencesWorker
  include Sidekiq::Worker

  def perform(status_id, ids, urls)
    ProcessReferencesService.new.call(Status.find(status_id), ids || [], urls: urls || [])
  rescue ActiveRecord::RecordNotFound
    true
  end
end
