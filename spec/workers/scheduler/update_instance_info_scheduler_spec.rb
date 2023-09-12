# frozen_string_literal: true

require 'rails_helper'

describe Scheduler::UpdateInstanceInfoScheduler do
  let(:worker) { described_class.new }

  before do
    stub_request(:get, 'https://example.com/.well-known/nodeinfo').to_return(status: 200, body: '{}')
    Fabricate(:account, domain: 'example.com')
    Instance.refresh
  end

  describe 'perform' do
    it 'runs without error' do
      expect { worker.perform }.to_not raise_error
    end
  end
end
