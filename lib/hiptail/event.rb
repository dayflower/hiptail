require 'hiptail/atom'

module HipTail
  class Event
    attr_accessor :authority
    attr_reader :raw

    # @return [HipTail::Event]
    def initialize(params)
      @raw = params.dup
    end

    # @attribute [r] type
    # @return [String]
    def type
      @raw['event']
    end

    # @attribute [r] oauth_client_id
    # @return [String]
    def oauth_client_id
      @raw['oauth_client_id']
    end

    # @attribute [r] webhook_id
    # @return [String]
    def webhook_id
      @raw['webhook_id']
    end

    class << self
      # @param [Hash] params
      # @return [HipTail::Event]
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
    # @abstract
    # @attribute [r] message
    # @return [HipTail::Messsage]
    def message
      raise
    end

    # @attribute [r] room
    # @return [HipTail::Room]
    def room
      @room ||= Room.new(@raw['item']['room'])
      @room
    end
  end

  class Event::RoomMessage < Event::RoomMessaging
    # @attribute [r] message
    # @return [HipTail::Messsage::Talk]
    def message
      @message ||= Message::Talk.new(@raw['item']['message'])
      @message
    end
  end

  class Event::RoomNotification < Event::RoomMessaging
    # @attribute [r] message
    # @return [HipTail::Messsage::Notification]
    def message
      @message ||= Message::Notification.new(@raw['item']['message'])
      @message
    end
  end

  class Event::RoomVisiting < Event
    # @attribute [r] sender
    # @return [HipTail::User]
    def sender
      @sender ||= User.create(@raw['item']['sender'])
      @sender
    end

    # @attribute [r] room
    # @return [HipTail::Room]
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
