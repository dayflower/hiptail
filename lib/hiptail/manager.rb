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
    def on_install(&block)
      register_hook :install, block
    end

    # Registers hook on uninstallation.
    # @return [String] Hook ID
    # @yield [oauth_id]
    # @yield [String] oauth_id
    def on_uninstall(&block)
      register_hook :uninstall, block
    end

    # Registers hook on events.
    # @return [String] Hook ID
    # @yield [authority, event]
    # @yield [HipTail::Authority] authority
    # @yield [HipTail::Event] event
    def on_event(&block)
      register_hook :event, block
    end

    # Registers hook on messaging events (room_message and room_notification).
    # @return [String] Hook ID
    # @yield [authority, event]
    # @yield [HipTail::Authority] authority
    # @yield [HipTail::Event::RoomMessaging] event
    def on_room_messaging(&block)
      register_hook :room_messaging, block
    end

    # Registers hook on room_message event.
    # @return [String] Hook ID
    # @yield [authority, event]
    # @yield [HipTail::Authority] authority
    # @yield [HipTail::Event::RoomMessage] event
    def on_room_message(&block)
      register_hook :room_message, block
    end

    # Registers hook on room_notification event.
    # @return [String] Hook ID
    # @yield [authority, event]
    # @yield [HipTail::Authority] authority
    # @yield [HipTail::Event::RoomNotification] event
    def on_room_notification(&block)
      register_hook :room_notification, block
    end

    # Registers hook on room visiting event (room_enter and room_exit).
    # @return [String] Hook ID
    # @yield [authority, event]
    # @yield [HipTail::Authority] authority
    # @yield [HipTail::Event::RoomVisiting] event
    def on_room_visiting(&block)
      register_hook :room_visiting, block
    end

    # Registers hook on room_enter event.
    # @return [String] Hook ID
    # @yield [authority, event]
    # @yield [HipTail::Authority] authority
    # @yield [HipTail::Event::RoomEnter] event
    def on_room_enter(&block)
      register_hook :room_enter, block
    end

    # Registers hook on room_exit event.
    # @return [String] Hook ID
    # @yield [authority, event]
    # @yield [HipTail::Authority] authority
    # @yield [HipTail::Event::RoomExit] event
    def on_room_exit(&block)
      register_hook :room_exit, block
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
      authority = self.authority[event.oauth_client_id]

      call_hooks :event, authority, event

      if event.is_a?(Event::RoomMessaging)
        call_hooks :room_messaging, authority, event

        case event
        when Event::RoomMessage
          call_hooks :room_message, authority, event
        when Event::RoomNotification
          call_hooks :room_notification, authority, event
        end
      elsif event.is_a?(Event::RoomVisiting)
        call_hooks :room_visiting, authority, event

        case event
        when Event::RoomEnter
          call_hooks :room_enter, authority, event
        when Event::RoomExit
          call_hooks :room_exit, authority, event
        end
      end
    end

    # Registers a hook.
    # @param [Symbol] hook_type
    # @param [Proc] block
    # @param [String] hook_id
    # @return [String] Hook ID
    def register_hook(hook_type, block, hook_id = nil)
      hook_id ||= block.object_id.to_s
      @hook[hook_type][hook_id] = block
      return hook_id
    end

    # Unregisters a hook.
    # @param [Symbol] hook_type
    # @param [String] hook_id
    # @return [Proc] Unregistered procedure
    def unregister_hook(hook_type, hook_id = nil)
      @hook[hook_type].delete(hook_id.to_s)
    end

    private

    def call_hooks(hook_type, *args)
      @hook[hook_type].values.each do |block|
        block.call(*args)
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
