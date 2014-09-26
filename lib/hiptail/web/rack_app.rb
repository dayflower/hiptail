require 'uri'
require 'rack'

require 'hiptail/web/handler'

module HipTail
  module Web; end

  class Web::RackApp
    # @return [HipTail::Manager] Returns HipTail::Manager.
    attr_reader :manager, :path

    # @param [Hash] params Capability parameters (and manager)
    # @option params [HipTail::Manager] :manager HipTail::Manager instance (optional)
    # @option params [String] :key Identical key for integration
    # @option params [String] :name integration name
    # @option params [String] :base_url Base URL for integration
    # @option params [String] :capability_url URL for capability
    # @option params [String] :webhook_url URL for event webhook
    # @option params [String] :installed_url URL for installed / uninstalled event webhook
    # @option params [String] :description (same as :name) integration description (optional)
    # @option params [String] :vendor_name (same as :name) Vendor name (optional)
    # @option params [String] :vendor_url (same as :base_url) Vendor URL (optional)
    # @option params [String] :homepage_url (same as :base_url) Homepage (optional)
    # @option params [String] :sender_name (same as :name) Name of notification sender (optional)
    # @option params [String] :allow_global (true) Allow global installation (optional)
    # @option params [String] :allow_room (true) Allow room installation (optional)
    # @option params [String] :message_filter Room message filter regexp (optional)
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
      @path = {
        :base => base_url.request_uri,
      }
      [ :webhook, :installed, :capability ].each do |key|
        @path[key] = base_url.merge('./' + params["#{key}_path".to_sym]).request_uri
      end

      @regex = {}
      @regex[:capability] = %r{\A #{Regexp.escape(@path[:capability])} \z}xm
      @regex[:event]      = %r{\A #{Regexp.escape(@path[:webhook])} \z}xm

      @regex[:install]   = %r{\A #{Regexp.escape(@path[:installed])} \z}xm
      @regex[:uninstall] = %r{\A #{Regexp.escape(@path[:installed])} / ([-0-9a-fA-F]+) \z}xm
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
