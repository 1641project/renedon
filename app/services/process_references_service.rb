# frozen_string_literal: true

class ProcessReferencesService < BaseService
  include Payloadable

  DOMAIN = ENV['WEB_DOMAIN'] || ENV.fetch('LOCAL_DOMAIN', nil)
  REFURL_EXP = /(RT|QT|BT|RN|RE)((:|;)?\s+|:|;)(#{URI::DEFAULT_PARSER.make_regexp(%w(http https))})/

  def call(status, reference_parameters, urls: nil)
    @status = status
    @reference_parameters = reference_parameters || []
    @urls = urls || []

    old_references

    return unless added_references.size.positive? || removed_references.size.positive?

    StatusReference.transaction do
      remove_old_references
      add_references

      @status.save!
    end

    create_notifications!
  end

  private

  def references
    @references = @reference_parameters + scan_text!
  end

  def old_references
    @old_references = @status.references.pluck(:id)
  end

  def added_references
    (references - old_references).uniq
  end

  def removed_references
    (old_references - references).uniq
  end

  def scan_text!
    text = @status.account.local? ? @status.text : @status.text.gsub(%r{</?[^>]*>}, '')
    @scan_text = fetch_statuses!(text.scan(REFURL_EXP).pluck(3).uniq).map(&:id).uniq.filter { |status_id| !status_id.zero? }
  end

  def fetch_statuses!(urls)
    (urls + @urls)
      .map { |url| ResolveURLService.new.call(url) }
      .filter { |status| status }
  end

  def add_references
    return if added_references.empty?

    @added_objects = []

    statuses = Status.where(id: added_references)
    statuses.each do |status|
      @added_objects << @status.reference_objects.new(target_status: status)
      status.increment_count!(:status_referred_by_count)
    end
  end

  def create_notifications!
    return if @added_objects.blank?

    local_reference_objects = @added_objects.filter { |ref| ref.target_status.account.local? }
    return if local_reference_objects.empty?

    LocalNotificationWorker.push_bulk(local_reference_objects) do |ref|
      [ref.target_status.account_id, ref.id, 'StatusReference', 'status_reference']
    end
  end

  def remove_old_references
    return if removed_references.empty?

    statuses = Status.where(id: removed_references)

    @status.reference_objects.where(target_status: statuses).destroy_all
    statuses.each do |status|
      status.decrement_count!(:status_referred_by_count)
    end
  end
end
