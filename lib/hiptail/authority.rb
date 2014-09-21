require 'json'
require 'uri'
require 'open-uri'
require 'net/http'
require 'oauth2'

module HipTail
  class Authority
    # @return [String] Returns OAuth ID.
    attr_reader :oauth_id
    # Returns room_id for room authority.
    # Nil for global authority.
    # @return [String]
    # @return [nil]
    attr_reader :room_id
    # Returns group_id for authority.
    # @return [String]
    attr_reader :group_id

    # @return [Boolean] Represents whether the authority is for global or not.
    def for_global?
      ! @room_id
    end
    alias global? for_global?

    # @return [Boolean] Represents whether the authority is for a room or not.
    def for_room?
      ! for_global?
    end
    alias room? for_room?

    # A new instance of HipTail::Authority.
    # @param [Hash] params
    # @option params [String] :oauth_id
    # @option params [String] :oauth_secret
    # @option params [String] :authorization_url
    # @option params [String] :token_url
    # @option params [String] :room_id
    # @option params [String] :group_id
    # @option params [String] :api_base
    # @return [HipTail::Authority]
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

    # @return [Hash] Hash representation.  Convenient for persistency.
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

    # Issues send notification API.
    # @param [Hash] params Parameters for notification API with :room_id.
    # @option params [String] :room_id Room ID. Optional but mandatory for global authority.
    # @return [Hash] Resulting response of API.
    def send_notification(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id
      call_api(:method => :post, :uri => @api_base.merge("room/#{room_id}/notification"), :body_params => params)
    end

    # Issues reply message API.
    # @param [Hash] params Parameters for reply message API with :room_id.
    # @option params [String] :room_id Room ID. Optional but mandatory for global authority.
    # @return [Hash] Resulting response of API.
    def reply_message(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id
      call_api(:method => :post, :uri => @api_base.merge("room/#{room_id}/reply"), :body_params => params)
    end

    # Issues get all rooms API.
    # @param [Hash] params Parameters for get all rooms API.
    # @return [HipTail::Rooms]
    def get_all_rooms(params = {})
      res = call_api(:method => :get, :uri => @api_base.merge("room"), :query_params => params)
      Rooms.new(res)
    end

    # Issues get room API.
    # @param [Hash] params Parameters for get all room API.
    # @option params [String] :room_id Room ID. Optional but mandatory for global authority.
    # @return [HipTail::Room::Detail]
    def get_room(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id
      res = call_api(:method => :get, :uri => @api_base.merge("room/#{room_id}"), :query_params => params)
      Room::Detail.new(res)
    end

    # Issues get all members API.
    # @param [Hash] params Parameters for get all members API.
    # @return [HipTail::Users]
    def get_all_members(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id
      res = call_api(:method => :get, :uri => @api_base.merge("room/#{room_id}/member"), :query_params => params)
      Users.new(res)
    end

    # Issues get all participants API.
    # @param [Hash] params Parameters for get all participants API.
    # @return [HipTail::Users]
    def get_all_participants(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id
      res = call_api(:method => :get, :uri => @api_base.merge("room/#{room_id}/participant"), :query_params => params)
      Users.new(res)
    end

    # Issues add member API.
    # @param [Hash] params Parameters for add member API with :room_id.
    # @option params [String] :room_id Room ID. Optional but mandatory for global authority.
    # @option params [String] :user_id One of :user_id, :user_mention, :user_email is required.
    # @option params [String] :user_mention
    # @option params [String] :user_email
    # @return [Hash] Resulting response of API.
    def add_member(params)
      room_id = self.room_id || params.delete(:room_id)
      raise ArgumentError.new("room_id required") unless room_id

      user_name = user_name_from_params(params)
      raise ArgumentError.new("user_id or user_mention or user_email required") unless user_name

      call_api(:method => :put, :uri => @api_base.merge("room/#{room_id}/member/#{user_name}"), :body_params => params)
    end

    # Issues remove member API.
    # @param [Hash] params Parameters for remove member API with :room_id.
    # @option params [String] :room_id Room ID. Optional but mandatory for global authority.
    # @option params [String] :user_id One of :user_id, :user_mention, :user_email is required.
    # @option params [String] :user_mention
    # @option params [String] :user_email
    # @return [Hash] Resulting response of API.
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
end
