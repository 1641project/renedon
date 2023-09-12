# frozen_string_literal: true

class ActivityPub::FetchInstanceInfoWorker
  include Sidekiq::Worker
  include JsonLdHelper
  include Redisable
  include Lockable

  sidekiq_options queue: 'push', retry: 2

  class Error < StandardError; end
  class GoneError < Error; end
  class RequestError < Error; end
  class DeadError < Error; end

  SUPPORTED_NOTEINFO_RELS = ['http://nodeinfo.diaspora.software/ns/schema/2.0', 'http://nodeinfo.diaspora.software/ns/schema/2.1'].freeze

  def perform(domain)
    @instance = Instance.find_by(domain: domain)
    return if !@instance || @instance.unavailable_domain.present?

    with_redis_lock("instance_info:#{domain}") do
      link = nodeinfo_link
      return if link.nil?

      update_info!(link)
    end
  rescue ActivityPub::FetchInstanceInfoWorker::DeadError
    true
  end

  private

  def nodeinfo_link
    nodeinfo = fetch_json("https://#{@instance.domain}/.well-known/nodeinfo")
    return nil if nodeinfo.nil? || !nodeinfo.key?('links')

    nodeinfo_links = nodeinfo['links']
    return nil if !nodeinfo_links.is_a?(Array) || nodeinfo_links.blank?

    nodeinfo_link = nodeinfo_links.find { |item| item.key?('rel') && item.key?('href') && SUPPORTED_NOTEINFO_RELS.include?(item['rel']) }
    return nil if nodeinfo_link.nil? || nodeinfo_link['href'].nil? || !nodeinfo_link['href'].start_with?('http')

    nodeinfo_link['href']
  end

  def update_info!(url)
    content = fetch_json(url)
    return nil if content.nil? || !content.key?('software') || !content['software'].key?('name')

    software = content['software']['name']
    version = content['software'].key?('version') ? content['software']['version'] : ''

    exists = @instance.instance_info
    if exists.nil?
      InstanceInfo.create!(domain: @instance.domain, software: software, version: version, data: content)
    else
      exists.software = software
      exists.version = version
      exists.data = content
      exists.save!
    end
  end

  def fetch_json(url)
    build_request(url).perform do |response|
      if [200, 203].include?(response.code)
        raise Mastodon::UnexpectedResponseError, response unless response_successful?(response) || response_error_unsalvageable?(response)

        body_to_json(response.body_with_limit)
      elsif response.code == 410
        raise ActivityPub::FetchInstanceInfoWorker::GoneError, "#{@instance.domain} is gone from the server"
      elsif response.code == 404
        raise ActivityPub::FetchInstanceInfoWorker::DeadError, "Request for #{@instance.domain} returned HTTP #{response.code}"
      else
        raise ActivityPub::FetchInstanceInfoWorker::RequestError, "Request for #{@instance.domain} returned HTTP #{response.code}"
      end
    end
  end

  def build_request(url)
    Request.new(:get, url).add_headers('Accept' => 'application/jrd+json, application/json')
  end
end
