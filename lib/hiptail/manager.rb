require 'ostruct'
require 'json'
require 'uri'
require 'open-uri'

require 'hiptail/event'
require 'hiptail/authority'
require 'hiptail/authority/provider'

module HipTail
  class Manager
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

    def authority
      @authority_manager
    end

    def on_install(&block)
      register_hook :install, block
    end

    def on_uninstall(&block)
      register_hook :uninstall, block
    end

    def on_event(&block)
      register_hook :event, block
    end

    def on_room_messaging(&block)
      register_hook :room_messaging, block
    end

    def on_room_message(&block)
      register_hook :room_message, block
    end

    def on_room_notification(&block)
      register_hook :room_notification, block
    end

    def on_room_visiting(&block)
      register_hook :room_visiting, block
    end

    def on_room_enter(&block)
      register_hook :room_enter, block
    end

    def on_room_exit(&block)
      register_hook :room_exit, block
    end

    def handle_install(params)
      authority = build_authority(params)

      @authority_provider.register(authority.oauth_id, authority)

      call_hooks :install, OpenStruct.new( :authority => authority )
    end

    def handle_uninstall(oauth_id)
      authority = self.authority[oauth_id]

      call_hooks :uninstall, OpenStruct.new( :authority => authority )

      @authority_provider.unregister(oauth_id)
    end

    def handle_event(params)
      event = Event.parse(params)
      authority = self.authority[event.oauth_client_id]

      hook_params = OpenStruct.new( :event => event, :authority => authority )
      call_hooks :event, hook_params

      if hook_params.event.is_a?(Event::RoomMessaging)
        call_hooks :room_messaging, hook_params

        case hook_params.event
        when Event::RoomMessage
          call_hooks :room_message, hook_params
        when Event::RoomNotification
          call_hooks :room_notification, hook_params
        end
      elsif hook_params.event.is_a?(Event::RoomVisiting)
        call_hooks :room_visiting, hook_params

        case hook_params.event
        when Event::RoomEnter
          call_hooks :room_enter, hook_params
        when Event::RoomExit
          call_hooks :room_exit, hook_params
        end
      end
    end

    def register_hook(hook_type, block, hook_id = nil)
      hook_id ||= block.object_id.to_s
      @hook[hook_type][hook_id] = block
      return hook_id
    end

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

    class AuthorityManager
      def initialize(authority_provider)
        @authority_provider = authority_provider
      end

      def [](oauth_id)
        @authority_provider.get(oauth_id)
      end
    end
  end
end
