# frozen_string_literal: true

require 'rails_helper'

describe Api::V1::Lists::AccountsController do
  render_views

  let(:user)  { Fabricate(:user) }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:list)  { Fabricate(:list, account: user.account) }

  before do
    follow = Fabricate(:follow, account: user.account)
    list.accounts << follow.target_account
    allow(controller).to receive(:doorkeeper_token) { token }
  end

  describe 'GET #index' do
    let(:scopes) { 'read:lists' }

    it 'returns http success' do
      get :show, params: { list_id: list.id }

      expect(response).to have_http_status(200)
    end
  end

  describe 'POST #create' do
    let(:scopes) { 'write:lists' }
    let(:bob) { Fabricate(:account, username: 'bob') }

    context 'when the added account is followed' do
      before do
        user.account.follow!(bob)
        post :create, params: { list_id: list.id, account_ids: [bob.id] }
      end

      it 'adds account to the list', :aggregate_failures do
        expect(response).to have_http_status(200)
        expect(list.accounts.include?(bob)).to be true
      end
    end

    context 'when the added account has been sent a follow request' do
      before do
        user.account.follow_requests.create!(target_account: bob)
        post :create, params: { list_id: list.id, account_ids: [bob.id] }
      end

      it 'adds account to the list', :aggregate_failures do
        expect(response).to have_http_status(200)
        expect(list.accounts.include?(bob)).to be true
      end
    end

    context 'when the added account is not followed' do
      before do
        post :create, params: { list_id: list.id, account_ids: [bob.id] }
      end

      it 'does not add the account to the list', :aggregate_failures do
        expect(response).to have_http_status(404)
        expect(list.accounts.include?(bob)).to be false
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:scopes) { 'write:lists' }

    before do
      delete :destroy, params: { list_id: list.id, account_ids: [list.accounts.first.id] }
    end

    it 'removes account from the list', :aggregate_failures do
      expect(response).to have_http_status(200)
      expect(list.accounts.count).to eq 0
    end
  end
end
