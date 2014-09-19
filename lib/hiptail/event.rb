require 'hiptail/atom'

module HipTail
  class Event
    attr_reader :raw

    def initialize(params)
      @raw = params.dup
    end

    def type
      @raw['event']
    end

    def oauth_client_id
      @raw['oauth_client_id']
    end

    def webhook_id
      @raw['webhook_id']
    end

    class << self
      def parse(params)
        type = params['event']

        case params['event']
        when 'room_message'
          return Event::RoomMessage.new(params)
        when 'room_notification'
          return Event::RoomNotification.new(params)
        when 'room_enter'
          return Event::RoomEnter.new(params)
        when 'room_exit'
          return Event::RoomExit.new(params)
        else
          return Event.new(params)
        end
      end
    end
  end

  class Event::RoomMessaging < Event
    def message
      @message ||= Message.new(@raw['item']['message'])
      @message
    end

    def room
      @room ||= Room.new(@raw['item']['room'])
      @room
    end
  end

  class Event::RoomMessage < Event::RoomMessaging
  end

  class Event::RoomNotification < Event::RoomMessaging
  end

  class Event::RoomVisiting < Event
    def sender
      @sender ||= User.create(@raw['item']['sender'])
      @sender
    end

    def room
      @room ||= Room.new(@raw['item']['room'])
      @room
    end
  end

  class Event::RoomEnter < Event::RoomVisiting
  end

  class Event::RoomExit < Event::RoomVisiting
  end
end
