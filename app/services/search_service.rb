# frozen_string_literal: true

class SearchService < BaseService
  def call(query, account, limit, options = {})
    @query   = query&.strip
    @account = account
    @options = options
    @limit   = limit.to_i
    @offset  = options[:type].blank? ? 0 : options[:offset].to_i
    @resolve = options[:resolve] || false
    @searchability = options[:searchability] || 'public'

    default_results.tap do |results|
      next if @query.blank? || @limit.zero?

      if url_query?
        results.merge!(url_resource_results) unless url_resource.nil? || @offset.positive? || (@options[:type].present? && url_resource_symbol != @options[:type].to_sym)
      elsif @query.present?
        results[:accounts] = perform_accounts_search! if account_searchable?
        results[:statuses] = perform_statuses_search! if full_text_searchable?
        results[:hashtags] = perform_hashtags_search! if hashtag_searchable?
      end
    end
  end

  private

  def perform_accounts_search!
    AccountSearchService.new.call(
      @query,
      @account,
      limit: @limit,
      resolve: @resolve,
      offset: @offset
    )
  end

  def perform_statuses_search!
    privacy_definition = parsed_query.apply(StatusesIndex.filter(term: { searchable_by: @account.id }))

    # 'private' searchability posts are NOT in here because it's already added at previous line.
    case @searchability
    when 'public'
      privacy_definition = privacy_definition.or(StatusesIndex.filter(term: { searchability: 'public' }))
      privacy_definition = privacy_definition.or(StatusesIndex.filter(term: { searchability: 'unlisted' }).filter(terms: { account_id: following_account_ids })) unless following_account_ids.empty?
      privacy_definition = privacy_definition.or(StatusesIndex.filter(term: { searchability: 'direct' }).filter(term: { account_id: @account.id }))
    when 'unlisted', 'private'
      privacy_definition = privacy_definition.or(StatusesIndex.filter(terms: { searchability: %w(public unlisted) }).filter(terms: { account_id: following_account_ids })) unless following_account_ids.empty?
      privacy_definition = privacy_definition.or(StatusesIndex.filter(term: { searchability: 'direct' }).filter(term: { account_id: @account.id }))
    when 'direct'
      privacy_definition = privacy_definition.or(StatusesIndex.filter(term: { searchability: 'direct' }).filter(term: { account_id: @account.id }))
    end

    definition = parsed_query.apply(StatusesIndex).order(id: :desc)
    definition = definition.filter(term: { account_id: @options[:account_id] }) if @options[:account_id].present?

    definition = definition.and(privacy_definition)

    if @options[:min_id].present? || @options[:max_id].present?
      range      = {}
      range[:gt] = @options[:min_id].to_i if @options[:min_id].present?
      range[:lt] = @options[:max_id].to_i if @options[:max_id].present?
      definition = definition.filter(range: { id: range })
    end

    results             = definition.limit(@limit).offset(@offset).objects.compact
    account_ids         = results.map(&:account_id)
    account_domains     = results.map(&:account_domain)
    account_relations   = relations_map_for_account(@account, account_ids, account_domains)  # old name: preloaded_relations

    results.reject { |status| StatusFilter.new(status, @account, account_relations).filtered? }
  rescue Faraday::ConnectionFailed, Parslet::ParseFailed
    []
  end

  def perform_hashtags_search!
    TagSearchService.new.call(
      @query,
      limit: @limit,
      offset: @offset,
      exclude_unreviewed: @options[:exclude_unreviewed]
    )
  end

  def default_results
    { accounts: [], hashtags: [], statuses: [] }
  end

  def url_query?
    @resolve && /\Ahttps?:\/\//.match?(@query)
  end

  def url_resource_results
    { url_resource_symbol => [url_resource] }
  end

  def url_resource
    @_url_resource ||= ResolveURLService.new.call(@query, on_behalf_of: @account)
  end

  def url_resource_symbol
    url_resource.class.name.downcase.pluralize.to_sym
  end

  def full_text_searchable?
    return false unless Chewy.enabled?

    statuses_search? && !@account.nil? && !((@query.start_with?('#') || @query.include?('@')) && !@query.include?(' '))
  end

  def account_searchable?
    account_search? && !(@query.start_with?('#') || (@query.include?('@') && @query.include?(' ')))
  end

  def hashtag_searchable?
    hashtag_search? && !@query.include?('@')
  end

  def account_search?
    @options[:type].blank? || @options[:type] == 'accounts'
  end

  def hashtag_search?
    @options[:type].blank? || @options[:type] == 'hashtags'
  end

  def statuses_search?
    @options[:type].blank? || @options[:type] == 'statuses'
  end

  def relations_map_for_account(account, account_ids, domains)
    {
      blocking: Account.blocking_map(account_ids, account.id),
      blocked_by: Account.blocked_by_map(account_ids, account.id),
      muting: Account.muting_map(account_ids, account.id),
      following: Account.following_map(account_ids, account.id),
      domain_blocking_by_domain: Account.domain_blocking_map_by_domain(domains, account.id),
    }
  end

  def parsed_query
    SearchQueryTransformer.new.apply(SearchQueryParser.new.parse(@query))
  end

  def following_account_ids
    return @following_account_ids if defined?(@following_account_ids)

    account_exists_sql     = Account.where('accounts.id = follows.target_account_id').where(searchability: %w(public unlisted private)).reorder(nil).select(1).to_sql
    status_exists_sql      = Status.where('statuses.account_id = follows.target_account_id').where(reblog_of_id: nil).where(searchability: %w(public unlisted private)).reorder(nil).select(1).to_sql
    following_accounts     = Follow.where(account_id: @account.id).merge(Account.where("EXISTS (#{account_exists_sql})").or(Account.where("EXISTS (#{status_exists_sql})")))
    @following_account_ids = following_accounts.pluck(:target_account_id)
  end
end
