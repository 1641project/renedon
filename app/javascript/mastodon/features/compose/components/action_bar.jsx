import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { defineMessages, injectIntl } from 'react-intl';

import ImmutablePropTypes from 'react-immutable-proptypes';

import DropdownMenuContainer from '../../../containers/dropdown_menu_container';

const messages = defineMessages({
  edit_profile: { id: 'account.edit_profile', defaultMessage: 'Edit profile' },
  pins: { id: 'navigation_bar.pins', defaultMessage: 'Pinned posts' },
  preferences: { id: 'navigation_bar.preferences', defaultMessage: 'Preferences' },
  reaction_deck: { id: 'navigation_bar.reaction_deck', defaultMessage: 'Reaction deck' },
  follow_requests: { id: 'navigation_bar.follow_requests', defaultMessage: 'Follow requests' },
  favourites: { id: 'navigation_bar.favourites', defaultMessage: 'Favorites' },
  emoji_reactions: { id: 'navigation_bar.emoji_reactions', defaultMessage: 'Stamps' },
  lists: { id: 'navigation_bar.lists', defaultMessage: 'Lists' },
  followed_tags: { id: 'navigation_bar.followed_tags', defaultMessage: 'Followed hashtags' },
  blocks: { id: 'navigation_bar.blocks', defaultMessage: 'Blocked users' },
  domain_blocks: { id: 'navigation_bar.domain_blocks', defaultMessage: 'Blocked domains' },
  mutes: { id: 'navigation_bar.mutes', defaultMessage: 'Muted users' },
  filters: { id: 'navigation_bar.filters', defaultMessage: 'Muted words' },
  antennas: { id: 'navigation_bar.antennas', defaultMessage: 'Antennas' },
  logout: { id: 'navigation_bar.logout', defaultMessage: 'Logout' },
  bookmarks: { id: 'navigation_bar.bookmarks', defaultMessage: 'Bookmarks' },
});

class ActionBar extends PureComponent {

  static propTypes = {
    account: ImmutablePropTypes.map.isRequired,
    onLogout: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  handleLogout = () => {
    this.props.onLogout();
  };

  render () {
    const { intl } = this.props;

    let menu = [];

    menu.push({ text: intl.formatMessage(messages.edit_profile), href: '/settings/profile' });
    menu.push({ text: intl.formatMessage(messages.preferences), href: '/settings/preferences' });
    menu.push({ text: intl.formatMessage(messages.reaction_deck), to: '/reaction_deck' });
    menu.push({ text: intl.formatMessage(messages.pins), to: '/pinned' });
    menu.push(null);
    menu.push({ text: intl.formatMessage(messages.follow_requests), to: '/follow_requests' });
    menu.push({ text: intl.formatMessage(messages.bookmarks), to: '/bookmark_categories' });
    menu.push({ text: intl.formatMessage(messages.favourites), to: '/favourites' });
    menu.push({ text: intl.formatMessage(messages.emoji_reactions), to: '/emoji_reactions' });
    menu.push({ text: intl.formatMessage(messages.lists), to: '/lists' });
    menu.push({ text: intl.formatMessage(messages.followed_tags), to: '/followed_tags' });
    menu.push(null);
    menu.push({ text: intl.formatMessage(messages.mutes), to: '/mutes' });
    menu.push({ text: intl.formatMessage(messages.blocks), to: '/blocks' });
    menu.push({ text: intl.formatMessage(messages.domain_blocks), to: '/domain_blocks' });
    menu.push({ text: intl.formatMessage(messages.filters), href: '/filters' });
    menu.push({ text: intl.formatMessage(messages.antennas), href: '/antennas' });
    menu.push(null);
    menu.push({ text: intl.formatMessage(messages.logout), action: this.handleLogout });

    return (
      <div className='compose__action-bar'>
        <div className='compose__action-bar-dropdown'>
          <DropdownMenuContainer items={menu} icon='bars' size={18} direction='right' />
        </div>
      </div>
    );
  }

}

export default injectIntl(ActionBar);
