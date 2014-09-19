require 'time'

module HipTail
  class User
    attr_reader :raw

    def initialize(params)
      @raw = params.dup
    end

    class << self
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
    def name
      @raw['name']
    end
  end

  class User::Person < User
    def id
      @raw['id']
    end

    def mention_name
      @raw['mention_name']
    end

    def name
      @raw['name']
    end
  end

  class Message
    attr_reader :raw

    def initialize(params)
      @raw = params.dup
    end

    def id
      @raw['id']
    end

    def date
      @date ||= Time.parse(@raw['date'])
      @date
    end

    def message
      @raw['message']
    end

    def message_format
      @raw['message_format']
    end

    def color
      @raw['color']
    end

    def from
      @from ||= User.create(@raw['from'])
      @from
    end

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

    def id
      @raw['id']
    end

    def name
      @raw['name']
    end
  end

  class Room::Detail < Room
    def created
      @created ||= Time.parse(@raw['created'])
      @created
    end

    def last_active
      @last_active ||= Time.parse(@raw['last_active'])
      @last_active
    end

    def privacy
      @raw['privacy']
    end

    def is_public
      privacy == 'public'
    end
    alias public? is_public

    def is_private
      privacy == 'private'
    end
    alias private? is_private

    def is_archived
      @raw['is_archived']
    end
    alias archived? is_archived

    def is_guest_accessible
      @raw['is_guest_accessible']
    end
    alias guest_accessible? is_guest_accessible

    def guest_access_url
      @raw['guest_access_url']
    end

    def owner
      @owner ||= User.new(@raw['owner'])
    end

    def participants
      @participants ||= @raw['participants'].map { |user| User.new(user) }
      @participants
    end

    def topic
      @raw['topic']
    end

    def xmpp_jid
      @raw['xmpp_jid']
    end
  end

  class Rooms
    attr_reader :raw

    def initialize(params)
      @raw = params.dup
    end

    def rooms
      @rooms ||= @raw['items'].map { |item| Room.new(item) }
      @rooms
    end

    def start_index
      @raw['startIndex']
    end

    def max_results
      @raw['maxResults']
    end
  end

  class Users
    attr_reader :raw

    def initialize(params)
      @raw = params.dup
    end

    def users
      @users ||= @raw['items'].map { |item| User.new(item) }
      @users
    end

    def start_index
      @raw['startIndex']
    end

    def max_results
      @raw['maxResults']
    end
  end
end
