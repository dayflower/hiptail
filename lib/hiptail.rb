require 'ostruct'
require 'time'
require 'json'
require 'uri'
require 'open-uri'
require 'net/http'
require 'oauth2'
require 'rack'

require 'hiptail/version'

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

  class Authority
    attr_reader :oauth_id
    attr_reader :room_id, :group_id

    def for_global?
      ! @room_id
    end
    alias global? for_global?

    def for_room?
      ! for_global?
    end
    alias room? for_room?

    def initialize(params)
      @oauth_id          = params[:oauth_id]
      @oauth_secret      = params[:oauth_secret]
      @authorization_url = params[:authorization_url]
      @token_url         = params[:token_url]

      @room_id           = params[:room_id]
      @group_id          = params[:group_id]

      @room_id  = @room_id.to_i  if ! @room_id.nil?
      @group_id = @group_id.to_i if ! @group_id.nil?

      api_base_uri = params[:api_base].to_s
      unless api_base_uri.end_with?('/')
        api_base_uri += '/';
      end
      @api_base = URI.parse(api_base_uri)
    end

    def as_hash
      {
        :oauth_id          => @oauth_id,
        :oauth_secret      => @oauth_secret,
        :authorization_url => @authorization_url,
        :token_url         => @token_url,
        :room_id           => @room_id,
        :group_id          => @group_id,
        :api_base          => @api_base,
      }
    end

    def send_notification(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id
      call_api(:method => :post, :uri => @api_base.merge("room/#{room_id}/notification"), :body_params => params)
    end

    def reply_message(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id
      call_api(:method => :post, :uri => @api_base.merge("room/#{room_id}/reply"), :body_params => params)
    end

    def get_all_rooms(params = {})
      res = call_api(:method => :get, :uri => @api_base.merge("room"), :query_params => params)
      Rooms.new(res)
    end

    def get_room(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id
      res = call_api(:method => :get, :uri => @api_base.merge("room/#{room_id}"), :query_params => params)
      Room::Detail.new(res)
    end

    def get_all_members(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id
      res = call_api(:method => :get, :uri => @api_base.merge("room/#{room_id}/member"), :query_params => params)
      Users.new(res)
    end

    def get_all_participants(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id
      res = call_api(:method => :get, :uri => @api_base.merge("room/#{room_id}/participant"), :query_params => params)
      Users.new(res)
    end

    def add_member(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id

      user_name = user_name_from_params(params)
      raise ArgumentError.new("user_id or user_mention or user_email required") unless user_name

      call_api(:method => :put, :uri => @api_base.merge("room/#{room_id}/member/#{user_name}"), :body_params => params)
    end

    def remove_member(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id

      user_name = user_name_from_params(params)
      raise ArgumentError.new("user_id or user_mention or user_email required") unless user_name

      call_api(:method => :delete, :uri => @api_base.merge("room/#{room_id}/member/#{user_name}"), :body_params => params)
    end

    private

    def user_name_from_params(params)
      user_id      = params.delete(:user_id)
      user_mention = params.delete(:user_mention)
      user_email   = params.delete(:user_email)

      return user_id if user_id
      return "@" + user_mention if user_mention
      return user_email if user_email
      return
    end

    def call_api(args)
      uri = URI.parse(args[:uri].to_s)
      queries = URI.decode_www_form(uri.query || '').map { |pair| [ pair[0].to_sym, pair[1] ] }
      # XXX Array or Hash, which is better?
      query = Hash[*queries.flatten(1)].merge(args[:query_params] || {})
      query[:auth_token] = token
      uri.query = query.size > 0 ? URI.encode_www_form(query) : nil

      headers = {
        'Content-Type' => 'application/json; charset=UTF-8',
      }

      if args[:body_params]
        body = JSON.generate(args[:body_params] || {})
        headers['Content-Length'] = body.bytesize.to_s
      else
        body = nil
      end

      case args[:method].to_s.downcase
      when 'get'
        req = Net::HTTP::Get.new(uri.request_uri, headers)
      when 'post'
        req = Net::HTTP::Post.new(uri.request_uri, headers)
      when 'put'
        req = Net::HTTP::Put.new(uri.request_uri, headers)
      when 'delete'
        req = Net::HTTP::Delete.new(uri.request_uri, headers)
      else
        raise
      end

      req.body = body if body

      res = http.start do |http|
        http.request(req)
      end

      if res.content_type =~ %r{\A application/json}x
        return JSON.parse(res.body)
      else
        return {}
      end
    end

    def token
      if !@token || @token.expired?
        @token = oauth2_client.client_credentials.get_token( :scope => "send_notification send_message admin_room view_group" )
      end

      @token.token
    end

    def oauth2_client
      unless @client
        @client = OAuth2::Client.new(
          @oauth_id, @oauth_secret,
          :authorize_url => @authorization_url,
          :token_url     => @token_url,
        )
      end

      @client
    end

    def http
      unless @http
        @http = Net::HTTP.new(@api_base.host, @api_base.port)
        @http.use_ssl = true if @api_base.scheme == 'https'
        @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        if ENV["DEBUG_HTTP"]
          @http.set_debug_output($stderr)
        end
      end

      @http.clone
    end
  end

  class AuthorityProvider
    def get(oauth_id)
      raise
    end

    def register(oauth_id, authority)
      raise
    end

    def unregister(oauth_id)
      raise
    end
  end

  class MemoryAuthorityProvider < AuthorityProvider
    def initialize
      @authorities = {}
    end

    def get(oauth_id)
      @authorities[oauth_id]
    end

    def register(oauth_id, authority)
      @authorities[oauth_id] = authority
    end

    def unregister(oauth_id)
      @authorities.delete(oauth_id)
    end
  end

  class Manager
    class AuthorityManager
      def initialize(authority_provider)
        @authority_provider = authority_provider
      end

      def [](oauth_id)
        @authority_provider.get(oauth_id)
      end
    end

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
  end

  module Web; end

  class Web::Handler
    attr_reader :manager

    def initialize(manager)
      @manager = manager
    end

    def handle_install(request)
      request.body.rewind
      @manager.handle_install(JSON.parse(request.body.read))
      create_response({})
    end

    def handle_uninstall(request, oauth_id)
      @manager.handle_uninstall(oauth_id)
      create_response({})
    end

    def handle_event(request)
      request.body.rewind
      @manager.handle_event(JSON.parse(request.body.read))
      create_response({})
    end

    def handle_capability(request, params)
      requireds = %w( key name
                      webhook_path installed_path )
      missings = requireds.select { |k| ! params.include?(k.to_sym) }
      if missings.length > 0
        raise "missing parameters: " + missings.join(%q{, })
      end
      params = params.dup

      params[:capability_url] = request.url.to_s

      base_url = URI.parse(request.url).merge(params[:base_path] || '/')
      params[:base_url] = base_url.to_s

      params[:webhook_url]   = base_url.merge('./' + params[:webhook_path])
      params[:installed_url] = base_url.merge('./' + params[:installed_path])

      cap = create_capability(params)
      create_response(cap)
    end

    def create_capability(params)
      requireds = %w( key name
                      base_url capability_url webhook_url installed_url )
      missings = requireds.select { |k| ! params.include?(k.to_sym) }
      if missings.length > 0
        raise "missing parameters: " + missings.join(%q{, })
      end

      capability = {
        key: params[:key],
        name: params[:name],
        description: params[:description] || params[:name],
        vendor: {
          name: params[:vendor_name] || params[:name],
          url: (params[:vendor_url] || params[:base_url]).to_s,
        },
        links: {
          self: params[:capability_url].to_s,
          homepage: (params[:homepage_url] || params[:base_url]).to_s,
        },
        capabilities: {
          webhook: [],
          hipchatApiConsumer: {
            scopes: %w( send_notification send_message admin_room view_group ),
            fromName: params[:sender_name] || params[:name],
          },
          installable: {
            allowGlobal: params.include?(:allow_global) ? params[:allow_global] : true,
            allowRoom: params.include?(:allow_room) ? params[:allow_room] : true,
            callbackUrl: params[:installed_url].to_s,
          }
        },
      }

      event_names = %w( room_notification room_topic_change
                        room_enter room_exit )

      webhook_url = params[:webhook_url].to_s
      capability[:capabilities][:webhook] = event_names.map { |key|
          {
            name: key,
            event: key,
            url: webhook_url,
          }
      }

      message_webhook = {
        name: 'room_message',
        event: 'room_message',
        url: webhook_url,
      }
      if params[:message_filter]
        message_webhook[:pattern] = params[:message_filter]
      end
      capability[:capabilities][:webhook] << message_webhook

      capability
    end

    def create_response(data, status = 200)
      body = JSON.generate(data)
      headers = {
        'Content-Type'   => 'application/json; charset=UTF-8',
        'Content-Length' => body.bytesize.to_s,
      }
      return [ status, headers, [ body ] ]
    end
  end

  class Web::RackApp
    attr_reader :manager

    def initialize(params)
      params = params.dup
      @manager = params.delete(:manager) || Manager.new
      @handler = Web::Handler.new(@manager)

      params[:base_path]       ||= '/'
      params[:webhook_path]    ||= '/event'
      params[:installed_path]  ||= '/install'
      params[:capability_path] ||= '/cap'
      @capability_params = params

      base_url = URI.parse('http://example.com/').merge(params[:base_path])
      path = {
        :base => base_url.request_uri,
      }
      [ :webhook, :installed, :capability ].each do |key|
        path[key] = base_url.merge('./' + params["#{key}_path".to_sym]).request_uri
      end

      @regex = {}
      @regex[:capability] = %r{\A #{Regexp.escape(path[:capability])} \z}xm
      @regex[:event]      = %r{\A #{Regexp.escape(path[:webhook])} \z}xm

      @regex[:install]   = %r{\A #{Regexp.escape(path[:installed])} \z}xm
      @regex[:uninstall] = %r{\A #{Regexp.escape(path[:installed])} / ([-0-9a-fA-F]+) \z}xm
    end

    def call(env)
      req = Rack::Request.new(env)

      case req.path_info
      when @regex[:capability]
        if req.get?
          return on_capability(req)
        end
      when @regex[:event]
        if req.post?
          return on_event(req)
        end
      when @regex[:install]
        if req.post?
          return on_install(req)
        end
      when @regex[:uninstall]
        if req.delete?
          return on_uninstall(req, $1)
        end
      end

      return @handler.create_response({}, 404)
    end

    private

    def on_capability(request)
      @capability_cached ||= @handler.handle_capability(request, @capability_params)
      @capability_cached
    end

    def on_event(request)
      @handler.handle_event(request)
    end

    def on_install(request)
      @handler.handle_install(request)
    end

    def on_uninstall(request, oauth_id)
      @handler.handle_uninstall(request, oauth_id)
    end
  end
end
