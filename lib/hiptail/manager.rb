require 'json'
require 'uri'
require 'open-uri'

require 'hiptail/event'
require 'hiptail/authority'
require 'hiptail/authority/provider'

module HipTail
  class Manager
    # A new instance of HipTail::Manager.
    # @param [Hash] params ({})
    # @option params [HipTail::AuthorityProvider] :authority_provider (new instance of HipTail::MemoryAuthorityProvider)
    # @return [HipTail::Manager]
    def initialize(params = {})
      @authority_provider = params[:authority_provider] || MemoryAuthorityProvider.new

      @authority_manager = AuthorityManager.new(@authority_provider)

      @hook = {}
      [
        :install, :uninstall,
        :event,
        :room_messaging, :room_message, :room_notification,
        :room_topic_change,
        :room_visiting,  :room_enter, :room_exit,
      ].each do |hook_type|
        @hook[hook_type] = {}
      end
    end

    # @return [HipTail::AuthorityProvider]
    attr_reader :authority_provider

    # @param [HipTail::AuthorityProvider] provider
    # @return [HipTail::AuthorityProvider]
    def authority_provider=(provider)
      @authority_provider = @authority_manager.authority_provider = provider
    end

    # Retrieves authority from oauth_id
    # @attribute [r] authority
    # @example
    #   authority = manager.authority[oauth_id]
    # @return [HipTail::Manager::AuthorityManager]
    def authority
      @authority_manager
    end

    # Registers hook on installation.
    # @return [String] Hook ID
    # @yield [authority]
    # @yield [HipTail::Authority] authority
    def on_install(*args, &block)
      register_hook :install, args, block
    end

    # Registers hook on uninstallation.
    # @return [String] Hook ID
    # @yield [oauth_id]
    # @yield [String] oauth_id
    def on_uninstall(*args, &block)
      register_hook :uninstall, args, block
    end

    # Registers hook on events.
    # @return [String] Hook ID
    # @yield [event]
    # @yield [HipTail::Event] event
    def on_event(*args, &block)
      register_hook :event, args, block
    end

    # Registers hook on messaging events (room_message and room_notification).
    # @return [String] Hook ID
    # @yield [event]
    # @yield [HipTail::Event::RoomMessaging] event
    def on_room_messaging(*args, &block)
      register_hook :room_messaging, args, block
    end

    # Registers hook on room_message event.
    # @return [String] Hook ID
    # @yield [event]
    # @yield [HipTail::Event::RoomMessage] event
    def on_room_message(*args, &block)
      register_hook :room_message, args, block
    end

    # Registers hook on room_notification event.
    # @return [String] Hook ID
    # @yield [event]
    # @yield [HipTail::Event::RoomNotification] event
    def on_room_notification(*args, &block)
      register_hook :room_notification, args, block
    end

    # Registers hook on room_topic_change event.
    # @return [String] Hook ID
    # @yield [event]
    # @yield [HipTail::Event::RoomTopicChange] event
    def on_room_topic_change(*args, &block)
      register_hook :room_topic_change, args, block
    end

    # Registers hook on room visiting event (room_enter and room_exit).
    # @return [String] Hook ID
    # @yield [event]
    # @yield [HipTail::Event::RoomVisiting] event
    def on_room_visiting(*args, &block)
      register_hook :room_visiting, args, block
    end

    # Registers hook on room_enter event.
    # @return [String] Hook ID
    # @yield [event]
    # @yield [HipTail::Event::RoomEnter] event
    def on_room_enter(*args, &block)
      register_hook :room_enter, args, block
    end

    # Registers hook on room_exit event.
    # @return [String] Hook ID
    # @yield [event]
    # @yield [HipTail::Event::RoomExit] event
    def on_room_exit(*args, &block)
      register_hook :room_exit, args, block
    end

    # Handles installing request.
    # @param [Hash] params Request object (originally represented in JSON) from HipChat Server on installation.
    # @return [void]
    def handle_install(params)
      authority = build_authority(params)

      @authority_provider.register(authority.oauth_id, authority)

      call_hooks :install, authority
    end

    # Handles uninstalling request.
    # @note Uninstall event will be fired after uninstallation on the server.
    #       So you cannot use oauth information to do something (e.g. sending notification) on uninstallation phase.
    # @param [String] oauth_id Corresponding OAuth ID
    # @return [void]
    def handle_uninstall(oauth_id)
      call_hooks :uninstall, oauth_id

      @authority_provider.unregister(oauth_id)
    end

    # Handles events (room_message, room_enter, etc.).
    # @param [Hash] params Request object (originally represented in JSON) from HipChat Server on installation.
    # @return [void]
    def handle_event(params)
      event = Event.parse(params)
      event.authority = self.authority[event.oauth_client_id]

      call_hooks :event, event

      if event.is_a?(Event::RoomMessaging)
        call_hooks :room_messaging, event

        case event
        when Event::RoomMessage
          call_hooks :room_message, event
        when Event::RoomNotification
          call_hooks :room_notification, event
        end
      elsif event.is_a?(Event::RoomTopicChange)
        call_hooks :room_topic_change, event
      elsif event.is_a?(Event::RoomVisiting)
        call_hooks :room_visiting, event

        case event
        when Event::RoomEnter
          call_hooks :room_enter, event
        when Event::RoomExit
          call_hooks :room_exit, event
        end
      end
    end

    # Registers a hook.
    # @param [Symbol] hook_type
    # @param [Proc] block
    # @param [String] hook_id
    # @return [String] Hook ID
    def register_hook(hook_type, args, block)
      priority = args.size > 0 ? args.shift : 100
      @hook[hook_type][priority] ||= []
      @hook[hook_type][priority] << block
    end

    private

    def call_hooks(hook_type, *args)
      @hook[hook_type].keys.sort.each do |key|
        @hook[hook_type][key].each do |block|
          aborted = false
          begin
            r = block.call(*args)
          rescue LocalJumpError => e
            aborted = e.reason
            raise e unless [:break, :next, :return].include?(aborted)
            r = e.exit_value
          end

          break if aborted == :break
        end
      end
    end

    def build_authority(params)
      server_cap = JSON.parse(URI.parse(params['capabilitiesUrl']).read)
      oauth2_info = server_cap['capabilities']['oauth2Provider']
      api_base    = server_cap['links']['api']

      HipTail::Authority.new(
        :oauth_id          => params['oauthId'],
        :oauth_secret      => params['oauthSecret'],
        :room_id           => params['roomId'],
        :group_id          => params['groupId'],
        :authorization_url => oauth2_info['authorizationUrl'],
        :token_url         => oauth2_info['tokenUrl'],
        :api_base          => server_cap['links']['api'],
      )
    end

    # @private
    class AuthorityManager
      # @return [HipTail::AuthorityProvider]
      attr_accessor :authority_provider

      # @param [HipTail::AuthorityProvider] authority_provider
      # @return [HipTail::Manager::AuthorityManager]
      def initialize(authority_provider)
        @authority_provider = authority_provider
      end

      # @param [String] oauth_id
      # @return [HipTail::Authority]
      def [](oauth_id)
        @authority_provider.get(oauth_id)
      end
    end
  end
end
