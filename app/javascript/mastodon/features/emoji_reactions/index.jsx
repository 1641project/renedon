import PropTypes from 'prop-types';

import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';

import { Helmet } from 'react-helmet';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';

import { fetchEmojiReactions } from 'mastodon/actions/interactions';
import ColumnHeader from 'mastodon/components/column_header';
import { Icon } from 'mastodon/components/icon';
import ScrollableList from 'mastodon/components/scrollable_list';
import AccountContainer from 'mastodon/containers/account_container';
import Column from 'mastodon/features/ui/components/column';


import EmojiView from '../../components/emoji_view';
import { LoadingIndicator } from '../../components/loading_indicator';

const messages = defineMessages({
  refresh: { id: 'refresh', defaultMessage: 'Refresh' },
});

const mapStateToProps = (state, props) => {
  return {
    accountIds: state.getIn(['user_lists', 'emoji_reactioned_by', props.params.statusId]),
  };
};

class EmojiReactions extends ImmutablePureComponent {

  static propTypes = {
    params: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    accountIds: ImmutablePropTypes.list,
    multiColumn: PropTypes.bool,
    intl: PropTypes.object.isRequired,
  };

  componentWillMount () {
    if (!this.props.accountIds) {
      this.props.dispatch(fetchEmojiReactions(this.props.params.statusId));
    }
  }

  componentWillReceiveProps (nextProps) {
    if (nextProps.params.statusId !== this.props.params.statusId && nextProps.params.statusId) {
      this.props.dispatch(fetchEmojiReactions(nextProps.params.statusId));
    }
  }

  handleRefresh = () => {
    this.props.dispatch(fetchEmojiReactions(this.props.params.statusId));
  };

  render () {
    const { intl, accountIds, multiColumn } = this.props;

    if (!accountIds) {
      return (
        <Column>
          <LoadingIndicator />
        </Column>
      );
    }

    let groups = {};
    for (const emoji_reaction of accountIds) {
      const key = emoji_reaction.account.id;
      const value = emoji_reaction;
      if (!groups[key]) groups[key] = [value];
      else groups[key].push(value);
    }

    const emptyMessage = <FormattedMessage id='empty_column.emoji_reactions' defaultMessage='No one has reacted with emoji this post yet. When someone does, they will show up here.' />;

    return (
      <Column bindToDocument={!multiColumn}>
        <ColumnHeader
          showBackButton
          multiColumn={multiColumn}
          extraButton={(
            <button type='button' className='column-header__button' title={intl.formatMessage(messages.refresh)} aria-label={intl.formatMessage(messages.refresh)} onClick={this.handleRefresh}><Icon id='refresh' /></button>
          )}
        />

        <ScrollableList
          scrollKey='emoji_reactions'
          emptyMessage={emptyMessage}
          bindToDocument={!multiColumn}
        >
          {Object.keys(groups).map((key) =>(
            <AccountContainer key={key} id={key} withNote={false} hideButtons>
              <div style={{ 'maxWidth': '100px' }}>
                {groups[key].map((value, index2) => <EmojiView key={index2} name={value.name} url={value.url} staticUrl={value.static_url} />)}
              </div>
            </AccountContainer>
          ))}
        </ScrollableList>

        <Helmet>
          <meta name='robots' content='noindex' />
        </Helmet>
      </Column>
    );
  }

}

export default connect(mapStateToProps)(injectIntl(EmojiReactions));
