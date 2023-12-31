# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::Activity::Create do
  let(:sender_bio) { '' }
  let(:sender) { Fabricate(:account, followers_url: 'http://example.com/followers', domain: 'example.com', uri: 'https://example.com/actor', note: sender_bio) }

  let(:json) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: [ActivityPub::TagManager.instance.uri_for(sender), '#foo'].join,
      type: 'Create',
      actor: ActivityPub::TagManager.instance.uri_for(sender),
      object: object_json,
    }.with_indifferent_access
  end

  before do
    sender.update(uri: ActivityPub::TagManager.instance.uri_for(sender))

    stub_request(:get, 'http://example.com/attachment.png').to_return(request_fixture('avatar.txt'))
    stub_request(:get, 'http://example.com/emoji.png').to_return(body: attachment_fixture('emojo.png'))
    stub_request(:get, 'http://example.com/emojib.png').to_return(body: attachment_fixture('emojo.png'), headers: { 'Content-Type' => 'application/octet-stream' })
  end

  describe '#perform' do
    context 'when fetching' do
      subject { described_class.new(json, sender) }

      let(:sender_software) { 'mastodon' }
      let(:custom_before) { false }
      let(:active_friend) { false }

      before do
        Fabricate(:instance_info, domain: 'example.com', software: sender_software)
        Fabricate(:friend_domain, domain: 'example.com', active_state: :accepted) if active_friend
        subject.perform unless custom_before
      end

      context 'when object has been edited' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            published: '2022-01-22T15:00:00Z',
            updated: '2022-01-22T16:00:00Z',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.text).to eq 'Lorem ipsum'
        end

        it 'marks status as edited' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.edited?).to be true
        end
      end

      context 'when object has update date equal to creation date' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            published: '2022-01-22T15:00:00Z',
            updated: '2022-01-22T15:00:00Z',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.text).to eq 'Lorem ipsum'
        end

        it 'does not mark status as edited' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.edited?).to be false
        end
      end

      context 'with an unknown object type' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Banana',
            content: 'Lorem ipsum',
          }
        end

        it 'does not create a status' do
          expect(sender.statuses.count).to be_zero
        end
      end

      context 'with a standalone' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.text).to eq 'Lorem ipsum'
        end

        it 'missing to/cc defaults to direct privacy' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'direct'
        end
      end

      context 'when public with explicit public address' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: 'https://www.w3.org/ns/activitystreams#Public',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'public'
        end
      end

      context 'when public with as:Public' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: 'as:Public',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'public'
        end
      end

      context 'when public with Public' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: 'Public',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'public'
        end
      end

      context 'when unlisted with explicit public address' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            cc: 'https://www.w3.org/ns/activitystreams#Public',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'unlisted'
        end
      end

      context 'when unlisted with as:Public' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            cc: 'as:Public',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'unlisted'
        end
      end

      context 'when unlisted with Public' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            cc: 'Public',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'unlisted'
        end
      end

      context 'when public_unlisted with kmyblue:LocalPublic' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: ['http://example.com/followers', 'kmyblue:LocalPublic'],
            cc: 'https://www.w3.org/ns/activitystreams#Public',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'unlisted'
        end
      end

      context 'when public_unlisted with kmyblue:LocalPublic from friend-server' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: ['http://example.com/followers', 'kmyblue:LocalPublic'],
            cc: 'https://www.w3.org/ns/activitystreams#Public',
          }
        end
        let(:active_friend) { true }

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'public_unlisted'
        end
      end

      context 'when private' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: 'http://example.com/followers',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'private'
        end
      end

      context 'when private with inlined Collection in audience' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: {
              type: 'OrderedCollection',
              id: 'http://example.com/followers',
              first: 'http://example.com/followers?page=true',
            },
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'private'
        end
      end

      context 'when limited' do
        let(:recipient) { Fabricate(:account) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: ActivityPub::TagManager.instance.uri_for(recipient),
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'limited'
          expect(status.limited_scope).to eq 'none'
        end

        it 'creates silent mention' do
          status = sender.statuses.first
          expect(status.mentions.first).to be_silent
        end
      end

      context 'when limited_scope' do
        let(:recipient) { Fabricate(:account) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: ActivityPub::TagManager.instance.uri_for(recipient),
            limitedScope: 'Mutual',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'limited'
          expect(status.limited_scope).to eq 'mutual'
        end
      end

      context 'when invalid limited_scope' do
        let(:recipient) { Fabricate(:account) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: ActivityPub::TagManager.instance.uri_for(recipient),
            limitedScope: 'IdosdsazsF',
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'limited'
          expect(status.limited_scope).to eq 'none'
        end
      end

      context 'when direct' do
        let(:recipient) { Fabricate(:account) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: ActivityPub::TagManager.instance.uri_for(recipient),
            tag: {
              type: 'Mention',
              href: ActivityPub::TagManager.instance.uri_for(recipient),
            },
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.visibility).to eq 'direct'
        end
      end

      context 'when searchability' do
        let(:searchable_by) { 'https://www.w3.org/ns/activitystreams#Public' }
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: 'https://www.w3.org/ns/activitystreams#Public',
            searchableBy: searchable_by,
          }
        end

        context 'with explicit public address' do
          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to eq 'public'
          end
        end

        context 'with public with as:Public' do
          let(:searchable_by) { 'as:Public' }

          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to eq 'public'
          end
        end

        context 'with public with Public' do
          let(:searchable_by) { 'Public' }

          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to eq 'public'
          end
        end

        context 'with public_unlisted with kmyblue:LocalPublic' do
          let(:searchable_by) { ['http://example.com/followers', 'kmyblue:LocalPublic'] }

          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to eq 'private'
          end
        end

        context 'with public_unlisted with kmyblue:LocalPublic from friend-server' do
          let(:searchable_by) { ['http://example.com/followers', 'kmyblue:LocalPublic'] }
          let(:active_friend) { true }

          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to eq 'public_unlisted'
          end
        end

        context 'with private' do
          let(:searchable_by) { 'http://example.com/followers' }

          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to eq 'private'
          end
        end

        context 'with direct' do
          let(:searchable_by) { '' }

          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to eq 'direct'
          end
        end

        context 'with direct when not specify' do
          let(:searchable_by) { nil }

          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to be_nil
          end
        end

        context 'with limited' do
          let(:searchable_by) { 'kmyblue:Limited' }

          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to eq 'limited'
          end
        end

        context 'with limited old spec' do
          let(:searchable_by) { 'as:Limited' }

          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to eq 'limited'
          end
        end

        context 'with bio' do
          let(:searchable_by) { nil }

          context 'with public' do
            let(:sender_bio) { '#searchable_by_all_users' }

            it 'create status' do
              status = sender.statuses.first

              expect(status).to_not be_nil
              expect(status.searchability).to eq 'public'
            end
          end

          context 'with private' do
            let(:sender_bio) { '#searchable_by_followers_only' }

            it 'create status' do
              status = sender.statuses.first

              expect(status).to_not be_nil
              expect(status.searchability).to eq 'private'
            end
          end

          context 'with direct' do
            let(:sender_bio) { '#searchable_by_reacted_users_only' }

            it 'create status' do
              status = sender.statuses.first

              expect(status).to_not be_nil
              expect(status.searchability).to eq 'direct'
            end
          end

          context 'with limited' do
            let(:sender_bio) { '#searchable_by_nobody' }

            it 'create status' do
              status = sender.statuses.first

              expect(status).to_not be_nil
              expect(status.searchability).to eq 'limited'
            end
          end

          context 'without hashtags' do
            let(:sender_bio) { '' }

            it 'create status' do
              status = sender.statuses.first

              expect(status).to_not be_nil
              expect(status.searchability).to be_nil
            end
          end
        end
      end

      context 'when searchability from misskey server' do
        let(:sender_software) { 'misskey' }
        let(:to) { 'https://www.w3.org/ns/activitystreams#Public' }
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: to,
          }
        end

        context 'without specify searchability from misskey' do
          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to eq 'public'
          end
        end

        context 'without specify searchability from misskey which visibility is private' do
          let(:to) { 'http://example.com/followers' }

          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to eq 'limited'
          end
        end
      end

      context 'with multible searchabilities' do
        let(:sender_bio) { '#searchable_by_nobody' }
        let(:searchable_by) { 'https://www.w3.org/ns/activitystreams#Public' }
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: 'https://www.w3.org/ns/activitystreams#Public',
            searchableBy: searchable_by,
          }
        end

        it 'create status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.searchability).to eq 'public'
        end

        context 'with misskey' do
          let(:sender_software) { 'misskey' }
          let(:searchable_by) { 'kmyblue:Limited' }

          it 'create status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
            expect(status.searchability).to eq 'limited'
          end
        end
      end

      context 'with a reply' do
        let(:original_status) { Fabricate(:status) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            inReplyTo: ActivityPub::TagManager.instance.uri_for(original_status),
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.thread).to eq original_status
          expect(status.reply?).to be true
          expect(status.in_reply_to_account).to eq original_status.account
          expect(status.conversation).to eq original_status.conversation
        end
      end

      context 'with mentions' do
        let(:recipient) { Fabricate(:account) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            tag: [
              {
                type: 'Mention',
                href: ActivityPub::TagManager.instance.uri_for(recipient),
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.mentions.map(&:account)).to include(recipient)
        end
      end

      context 'with mentions missing href' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            tag: [
              {
                type: 'Mention',
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first
          expect(status).to_not be_nil
        end
      end

      context 'with mentions domain block reject_reply' do
        before do
          Fabricate(:domain_block, domain: 'example.com', severity: :noop, reject_reply: true)
          subject.perform
        end

        let(:custom_before) { true }
        let(:recipient) { Fabricate(:account) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            tag: [
              {
                type: 'Mention',
                href: ActivityPub::TagManager.instance.uri_for(recipient),
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to be_nil
        end
      end

      context 'with mentions domain block reject_reply_exclude_followers' do
        before do
          Fabricate(:domain_block, domain: 'example.com', severity: :noop, reject_reply_exclude_followers: true)
          recipient.follow!(sender) if follow
          subject.perform
        end

        let(:custom_before) { true }
        let(:follow) { false }
        let(:recipient) { Fabricate(:account) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            tag: [
              {
                type: 'Mention',
                href: ActivityPub::TagManager.instance.uri_for(recipient),
              },
            ],
          }
        end

        context 'when follower' do
          let(:follow) { true }

          it 'creates status' do
            status = sender.statuses.first

            expect(status).to_not be_nil
          end
        end

        context 'when not follower' do
          it 'creates status' do
            status = sender.statuses.first

            expect(status).to be_nil
          end
        end
      end

      context 'with media attachments' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            attachment: [
              {
                type: 'Document',
                mediaType: 'image/png',
                url: 'http://example.com/attachment.png',
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.media_attachments.map(&:remote_url)).to include('http://example.com/attachment.png')
        end
      end

      context 'with media attachments with long description' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            attachment: [
              {
                type: 'Document',
                mediaType: 'image/png',
                url: 'http://example.com/attachment.png',
                name: '*' * 1500,
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.media_attachments.map(&:description)).to include('*' * 1500)
        end
      end

      context 'with media attachments with long description as summary' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            attachment: [
              {
                type: 'Document',
                mediaType: 'image/png',
                url: 'http://example.com/attachment.png',
                summary: '*' * 1500,
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.media_attachments.map(&:description)).to include('*' * 1500)
        end
      end

      context 'with media attachments with focal points' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            attachment: [
              {
                type: 'Document',
                mediaType: 'image/png',
                url: 'http://example.com/attachment.png',
                focalPoint: [0.5, -0.7],
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.media_attachments.map(&:focus)).to include('0.5,-0.7')
        end
      end

      context 'with media attachments missing url' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            attachment: [
              {
                type: 'Document',
                mediaType: 'image/png',
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first
          expect(status).to_not be_nil
        end
      end

      context 'with hashtags' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            tag: [
              {
                type: 'Hashtag',
                href: 'http://example.com/blah',
                name: '#test',
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.tags.map(&:name)).to include('test')
        end
      end

      context 'with hashtags missing name' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            tag: [
              {
                type: 'Hashtag',
                href: 'http://example.com/blah',
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first
          expect(status).to_not be_nil
        end
      end

      context 'with hashtags invalid name' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            tag: [
              {
                type: 'Hashtag',
                href: 'http://example.com/blah',
                name: 'foo, #eh !',
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first
          expect(status).to_not be_nil
        end
      end

      context 'with emojis' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum :tinking:',
            tag: [
              {
                type: 'Emoji',
                icon: {
                  url: 'http://example.com/emoji.png',
                },
                name: 'tinking',
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.emojis.map(&:shortcode)).to include('tinking')
        end
      end

      context 'with emojis served with invalid content-type' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum :tinkong:',
            tag: [
              {
                type: 'Emoji',
                icon: {
                  url: 'http://example.com/emojib.png',
                },
                name: 'tinkong',
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.emojis.map(&:shortcode)).to include('tinkong')
        end
      end

      context 'with emojis missing name' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum :tinking:',
            tag: [
              {
                type: 'Emoji',
                icon: {
                  url: 'http://example.com/emoji.png',
                },
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first
          expect(status).to_not be_nil
        end
      end

      context 'with emojis missing icon' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum :tinking:',
            tag: [
              {
                type: 'Emoji',
                name: 'tinking',
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first
          expect(status).to_not be_nil
        end
      end

      context 'with poll' do
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Question',
            content: 'Which color was the submarine?',
            oneOf: [
              {
                name: 'Yellow',
                replies: {
                  type: 'Collection',
                  totalItems: 10,
                },
              },
              {
                name: 'Blue',
                replies: {
                  type: 'Collection',
                  totalItems: 3,
                },
              },
            ],
          }
        end

        it 'creates status' do
          status = sender.statuses.first
          expect(status).to_not be_nil
          expect(status.poll).to_not be_nil
        end

        it 'creates a poll' do
          poll = sender.polls.first
          expect(poll).to_not be_nil
          expect(poll.status).to_not be_nil
          expect(poll.options).to eq %w(Yellow Blue)
          expect(poll.cached_tallies).to eq [10, 3]
        end
      end

      context 'when a vote to a local poll' do
        let(:poll) { Fabricate(:poll, options: %w(Yellow Blue)) }
        let!(:local_status) { Fabricate(:status, poll: poll) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            name: 'Yellow',
            inReplyTo: ActivityPub::TagManager.instance.uri_for(local_status),
          }
        end

        it 'adds a vote to the poll with correct uri' do
          vote = poll.votes.first
          expect(vote).to_not be_nil
          expect(vote.uri).to eq object_json[:id]
          expect(poll.reload.cached_tallies).to eq [1, 0]
        end
      end

      context 'when a vote to an expired local poll' do
        let(:poll) do
          poll = Fabricate.build(:poll, options: %w(Yellow Blue), expires_at: 1.day.ago)
          poll.save(validate: false)
          poll
        end
        let!(:local_status) { Fabricate(:status, poll: poll) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            name: 'Yellow',
            inReplyTo: ActivityPub::TagManager.instance.uri_for(local_status),
          }
        end

        it 'does not add a vote to the poll' do
          expect(poll.votes.first).to be_nil
        end
      end

      context 'with references' do
        let(:recipient) { Fabricate(:account) }
        let!(:target_status) { Fabricate(:status, account: Fabricate(:account, domain: nil)) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            references: {
              id: 'target_status',
              type: 'Collection',
              first: {
                type: 'CollectionPage',
                next: nil,
                partOf: 'target_status',
                items: [
                  ActivityPub::TagManager.instance.uri_for(target_status),
                ],
              },
            },
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.quote).to be_nil
          expect(status.references.pluck(:id)).to eq [target_status.id]
        end
      end

      context 'with quote' do
        let(:recipient) { Fabricate(:account) }
        let!(:target_status) { Fabricate(:status, account: Fabricate(:account, domain: nil)) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            quote: ActivityPub::TagManager.instance.uri_for(target_status),
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.references.pluck(:id)).to eq [target_status.id]
          expect(status.quote).to_not be_nil
          expect(status.quote.id).to eq target_status.id
        end
      end

      context 'with references and quote' do
        let(:recipient) { Fabricate(:account) }
        let!(:target_status) { Fabricate(:status, account: Fabricate(:account, domain: nil)) }

        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            quote: ActivityPub::TagManager.instance.uri_for(target_status),
            references: {
              id: 'target_status',
              type: 'Collection',
              first: {
                type: 'CollectionPage',
                next: nil,
                partOf: 'target_status',
                items: [
                  ActivityPub::TagManager.instance.uri_for(target_status),
                ],
              },
            },
          }
        end

        it 'creates status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.references.pluck(:id)).to eq [target_status.id]
          expect(status.quote).to_not be_nil
          expect(status.quote.id).to eq target_status.id
        end
      end

      context 'with language' do
        let(:to) { 'https://www.w3.org/ns/activitystreams#Public' }
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: to,
            contentMap: { ja: 'Lorem ipsum' },
          }
        end

        it 'create status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.language).to eq 'ja'
        end
      end

      context 'without language' do
        let(:to) { 'https://www.w3.org/ns/activitystreams#Public' }
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: to,
          }
        end

        it 'create status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.language).to be_nil
        end
      end

      context 'without language when misskey server' do
        let(:sender_software) { 'misskey' }
        let(:to) { 'https://www.w3.org/ns/activitystreams#Public' }
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: to,
          }
        end

        it 'create status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.language).to eq 'ja'
        end
      end

      context 'with language when misskey server' do
        let(:sender_software) { 'misskey' }
        let(:to) { 'https://www.w3.org/ns/activitystreams#Public' }
        let(:object_json) do
          {
            id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
            type: 'Note',
            content: 'Lorem ipsum',
            to: to,
            contentMap: { 'en-US': 'Lorem ipsum' },
          }
        end

        it 'create status' do
          status = sender.statuses.first

          expect(status).to_not be_nil
          expect(status.language).to eq 'en-US'
        end
      end
    end

    context 'with an encrypted message' do
      subject { described_class.new(json, sender, delivery: true, delivered_to_account_id: recipient.id) }

      let(:recipient) { Fabricate(:account) }
      let(:object_json) do
        {
          id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
          type: 'EncryptedMessage',
          attributedTo: {
            type: 'Device',
            deviceId: '1234',
          },
          to: {
            type: 'Device',
            deviceId: target_device.device_id,
          },
          messageType: 1,
          cipherText: 'Foo',
          messageFranking: 'Baz678',
          digest: {
            digestAlgorithm: 'Bar456',
            digestValue: 'Foo123',
          },
        }
      end
      let(:target_device) { Fabricate(:device, account: recipient) }

      before do
        subject.perform
      end

      it 'creates an encrypted message' do
        encrypted_message = target_device.encrypted_messages.reload.first

        expect(encrypted_message).to_not be_nil
        expect(encrypted_message.from_device_id).to eq '1234'
        expect(encrypted_message.from_account).to eq sender
        expect(encrypted_message.type).to eq 1
        expect(encrypted_message.body).to eq 'Foo'
        expect(encrypted_message.digest).to eq 'Foo123'
      end

      it 'creates a message franking' do
        encrypted_message = target_device.encrypted_messages.reload.first
        message_franking  = encrypted_message.message_franking

        crypt = ActiveSupport::MessageEncryptor.new(SystemKey.current_key, serializer: Oj)
        json  = crypt.decrypt_and_verify(message_franking)

        expect(json['source_account_id']).to eq sender.id
        expect(json['target_account_id']).to eq recipient.id
        expect(json['original_franking']).to eq 'Baz678'
      end
    end

    context 'when sender is followed by local users' do
      subject { described_class.new(json, sender, delivery: true) }

      before do
        Fabricate(:account).follow!(sender)
        subject.perform
      end

      let(:object_json) do
        {
          id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
          type: 'Note',
          content: 'Lorem ipsum',
        }
      end

      it 'creates status' do
        status = sender.statuses.first

        expect(status).to_not be_nil
        expect(status.text).to eq 'Lorem ipsum'
      end
    end

    context 'when sender replies to local status' do
      subject { described_class.new(json, sender, delivery: true) }

      let!(:local_status) { Fabricate(:status) }
      let(:object_json) do
        {
          id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
          type: 'Note',
          content: 'Lorem ipsum',
          inReplyTo: ActivityPub::TagManager.instance.uri_for(local_status),
        }
      end

      before do
        subject.perform
      end

      it 'creates status' do
        status = sender.statuses.first

        expect(status).to_not be_nil
        expect(status.text).to eq 'Lorem ipsum'
      end
    end

    context 'when sender quotes to local status' do
      subject { described_class.new(json, sender, delivery: true) }

      let!(:local_status) { Fabricate(:status) }
      let(:object_json) do
        {
          id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
          type: 'Note',
          content: 'Lorem ipsum',
          quote: ActivityPub::TagManager.instance.uri_for(local_status),
        }
      end

      before do
        subject.perform
      end

      it 'creates status' do
        status = sender.statuses.first

        expect(status).to_not be_nil
        expect(status.text).to eq 'Lorem ipsum'
      end
    end

    context 'when sender quotes to non-local status' do
      subject { described_class.new(json, sender, delivery: true) }

      let!(:remote_status) { Fabricate(:status, uri: 'https://foo.bar/among', account: Fabricate(:account, domain: 'foo.bar', uri: 'https://foo.bar/account')) }
      let(:object_json) do
        {
          id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
          type: 'Note',
          content: 'Lorem ipsum',
          quote: ActivityPub::TagManager.instance.uri_for(remote_status),
        }
      end

      before do
        subject.perform
      end

      it 'creates status' do
        expect(sender.statuses.count).to eq 0
      end
    end

    context 'when sender targets a local user' do
      subject { described_class.new(json, sender, delivery: true) }

      let!(:local_account) { Fabricate(:account) }
      let(:object_json) do
        {
          id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
          type: 'Note',
          content: 'Lorem ipsum',
          to: ActivityPub::TagManager.instance.uri_for(local_account),
        }
      end

      before do
        subject.perform
      end

      it 'creates status' do
        status = sender.statuses.first

        expect(status).to_not be_nil
        expect(status.text).to eq 'Lorem ipsum'
      end
    end

    context 'when sender cc\'s a local user' do
      subject { described_class.new(json, sender, delivery: true) }

      let!(:local_account) { Fabricate(:account) }
      let(:object_json) do
        {
          id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
          type: 'Note',
          content: 'Lorem ipsum',
          cc: ActivityPub::TagManager.instance.uri_for(local_account),
        }
      end

      before do
        subject.perform
      end

      it 'creates status' do
        status = sender.statuses.first

        expect(status).to_not be_nil
        expect(status.text).to eq 'Lorem ipsum'
      end
    end

    context 'when sender is in friend server' do
      subject { described_class.new(json, sender, delivery: true) }

      let!(:friend) { Fabricate(:friend_domain, domain: sender.domain, active_state: :accepted) }
      let(:object_json) do
        {
          id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
          type: 'Note',
          content: 'Lorem ipsum',
        }
      end

      it 'creates status' do
        subject.perform
        status = sender.statuses.first

        expect(status).to_not be_nil
        expect(status.text).to eq 'Lorem ipsum'
      end

      it 'whey no-relay not creates status' do
        friend.update(allow_all_posts: false)
        subject.perform
        status = sender.statuses.first

        expect(status).to be_nil
      end
    end

    context 'when the sender has no relevance to local activity' do
      subject { described_class.new(json, sender, delivery: true) }

      before do
        subject.perform
      end

      let(:object_json) do
        {
          id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
          type: 'Note',
          content: 'Lorem ipsum',
        }
      end

      it 'does not create anything' do
        expect(sender.statuses.count).to eq 0
      end
    end

    context 'when bearcaps' do
      subject { described_class.new(json, sender) }

      before do
        stub_request(:get, 'https://example.com/statuses/1234567890')
          .with(headers: { 'Authorization' => 'Bearer test_ohagi_token' })
          .to_return(status: 200, body: Oj.dump(object_json), headers: {})

        subject.perform
      end

      let!(:recipient) { Fabricate(:account) }
      let(:object_json) do
        {
          id: 'https://example.com/statuses/1234567890',
          type: 'Note',
          content: 'Lorem ipsum',
          to: ActivityPub::TagManager.instance.uri_for(recipient),
          attachment: [
            {
              type: 'Document',
              mediaType: 'image/png',
              url: 'http://example.com/attachment.png',
            },
          ],
        }
      end
      let(:json) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: [ActivityPub::TagManager.instance.uri_for(sender), '#bar'].join,
          type: 'Create',
          actor: ActivityPub::TagManager.instance.uri_for(sender),
          object: "bear:?#{{ u: 'https://example.com/statuses/1234567890', t: 'test_ohagi_token' }.to_query}",
        }.with_indifferent_access
      end

      it 'creates status' do
        status = sender.statuses.first

        expect(status).to_not be_nil
        expect(status.text).to eq 'Lorem ipsum'
        expect(status.mentions.map(&:account)).to include(recipient)
        expect(status.mentions.count).to eq 1
        expect(status.visibility).to eq 'limited'
        expect(status.media_attachments.map(&:remote_url)).to include('http://example.com/attachment.png')
      end
    end
  end
end
