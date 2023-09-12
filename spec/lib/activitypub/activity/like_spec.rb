# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::Activity::Like do
  let(:sender)    { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/') }
  let(:recipient) { Fabricate(:account) }
  let(:status)    { Fabricate(:status, account: recipient) }

  let(:json) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: 'foo',
      type: 'Like',
      actor: ActivityPub::TagManager.instance.uri_for(sender),
      object: ActivityPub::TagManager.instance.uri_for(status),
    }.with_indifferent_access
  end

  describe '#perform' do
    subject { described_class.new(json, sender) }

    before do
      subject.perform
    end

    it 'creates a favourite from sender to status' do
      expect(sender.favourited?(status)).to be true
    end
  end

  describe '#perform when domain_block' do
    subject { described_class.new(json, sender) }

    before do
      Fabricate(:domain_block, domain: 'example.com', severity: :noop, reject_favourite: true)
      subject.perform
    end

    it 'does not create a favourite from sender to status' do
      expect(sender.favourited?(status)).to be false
    end
  end

  describe '#perform when normal domain_block' do
    subject { described_class.new(json, sender) }

    before do
      Fabricate(:domain_block, domain: 'example.com', severity: :suspend)
      subject.perform
    end

    it 'does not create a favourite from sender to status', pending: 'considering spec' do
      expect(sender.favourited?(status)).to be false
    end
  end

  describe '#perform when account domain_block' do
    subject { described_class.new(json, sender) }

    before do
      Fabricate(:account_domain_block, account: recipient, domain: 'example.com')
      subject.perform
    end

    it 'does not create a favourite from sender to status', pending: 'considering spec' do
      expect(sender.favourited?(status)).to be false
    end
  end
end
