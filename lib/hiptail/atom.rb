require 'time'

module HipTail
  class User
    attr_reader :raw

    # @return [HipTail::User]
    def initialize(params)
      @raw = params.dup
    end

    class << self
      # @return [HipTail::User]
      def create(params)
        if params.is_a?(String)
          return User::Notify.new({ :name => params })
        else
          return User::Person.new(params)
        end
      end
    end
  end

  class User::Notify < User
    # @attribute [r] name
    # @return [String]
    def name
      @raw['name']
    end
  end

  class User::Person < User
    # @attribute [r] id
    # @return [String]
    def id
      @raw['id']
    end

    # @attribute [r] mention_name
    # @return [String]
    def mention_name
      @raw['mention_name']
    end

    # @attribute [r] name
    # @return [String]
    def name
      @raw['name']
    end
  end

  class Message
    attr_reader :raw

    def initialize(params)
      @raw = params.dup
    end

    # @attribute [r] id
    # @return [String]
    def id
      @raw['id']
    end

    # @attribute [r] date
    # @return [Time]
    def date
      @date ||= Time.parse(@raw['date'])
      @date
    end

    # @attribute [r] message
    # @return [String]
    def message
      @raw['message']
    end

    # @attribute [r] message_format
    # @return [String]
    def message_format
      @raw['message_format']
    end

    # @attribute [r] color
    # @return [String]
    def color
      @raw['color']
    end

    # @attribute [r] from
    # @return [HipTail::User]
    def from
      @from ||= User.create(@raw['from'])
      @from
    end

    # @attribute [r] mentions
    # @return [Array] Array of HipTail::User.
    def mentions
      @mentions ||= (@raw['mentions'] || []).map { |data| User.create(data) }
      @mentions
    end
  end

  class Room
    attr_reader :raw

    def initialize(params)
      @raw = params.dup
    end

    def detailed?
      false
    end

    # @attribute [r] id
    # @return [String]
    def id
      @raw['id']
    end

    # @attribute [r] name
    # @return [String]
    def name
      @raw['name']
    end
  end

  class Room::Detail < Room
    # @attribute [r] created
    # @return [Time]
    def created
      @created ||= Time.parse(@raw['created'])
      @created
    end

    # @attribute [r] last_active
    # @return [Time]
    def last_active
      @last_active ||= Time.parse(@raw['last_active'])
      @last_active
    end

    # @attribute [r] privacy
    # @return [String]
    def privacy
      @raw['privacy']
    end

    # @attribute [r] is_public
    # @return [Boolean]
    def is_public
      privacy == 'public'
    end
    alias public? is_public

    # @attribute [r] is_private
    # @return [Boolean]
    def is_private
      privacy == 'private'
    end
    alias private? is_private

    # @attribute [r] is_archived
    # @return [Boolean]
    def is_archived
      @raw['is_archived']
    end
    alias archived? is_archived

    # @attribute [r] is_guest_accessible
    # @return [Boolean]
    def is_guest_accessible
      @raw['is_guest_accessible']
    end
    alias guest_accessible? is_guest_accessible

    # @attribute [r] guest_access_url
    # @return [String]
    def guest_access_url
      @raw['guest_access_url']
    end

    # @attribute [r] owner
    # @return [User]
    def owner
      @owner ||= User.new(@raw['owner'])
    end

    # @attribute [r] participants
    # @return [Array] Array of HipTail::User.
    def participants
      @participants ||= @raw['participants'].map { |user| User.new(user) }
      @participants
    end

    # @attribute [r] topic
    # @return [String]
    def topic
      @raw['topic']
    end

    # @attribute [r] xmpp_jid
    # @return [String]
    def xmpp_jid
      @raw['xmpp_jid']
    end
  end

  class Rooms
    attr_reader :raw

    def initialize(params)
      @raw = params.dup
    end

    # @attribute [r] rooms
    # @return [Array] Array of HipTail::Room.
    def rooms
      @rooms ||= @raw['items'].map { |item| Room.new(item) }
      @rooms
    end

    # @attribute [r] start_index
    def start_index
      @raw['startIndex']
    end

    # @attribute [r] max_results
    def max_results
      @raw['maxResults']
    end
  end

  class Users
    attr_reader :raw

    def initialize(params)
      @raw = params.dup
    end

    # @attribute [r] users
    # @return [Array] Array of HipTail::User.
    def users
      @users ||= @raw['items'].map { |item| User.new(item) }
      @users
    end

    # @attribute [r] start_index
    def start_index
      @raw['startIndex']
    end

    # @attribute [r] max_results
    def max_results
      @raw['maxResults']
    end
  end
end
