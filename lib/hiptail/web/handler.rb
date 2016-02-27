require 'json'
require 'uri'
require 'hiptail/util'

module HipTail
  module Web; end

  class Web::Handler
    # @return [HipTail::Manager] Returns HipTail::Manager.
    attr_reader :manager

    # @param [HipTail::Manager] manager
    def initialize(manager)
      @manager = manager
    end

    # Handles installing request.
    # @param [Rack::Request] request
    # @return [Array] Rack response.
    def handle_install(request)
      request.body.rewind
      @manager.handle_install(JSON.parse(request.body.read))
      create_response({})
    end

    # Handles uninstalling request.
    # @note Uninstall event will be fired after uninstallation on the server.
    #       So you cannot use oauth information to do something (e.g. sending notification) on uninstallation phase.
    # @param [Rack::Request] request
    # @param [String] oauth_id Corresponding OAuth ID
    # @return [Array] Rack response.
    def handle_uninstall(request, oauth_id)
      @manager.handle_uninstall(oauth_id)
      create_response({})
    end

    # Handles events (room_message, room_enter, etc.).
    # @param [Rack::Request] request
    # @return [Array] Rack response.
    def handle_event(request)
      request.body.rewind
      @manager.handle_event(JSON.parse(request.body.read))
      create_response({})
    end

    # Handles retrieving capability request.
    # @param [Rack::Request] request
    # @param [Hash] params Capability parameters
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
    # @return [Array] Rack response.
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

      capability = HipTail::Util::create_capability(params)
      if block_given?
        yield capability
      end
      create_response(capability)
    end

    # @param [Hash] data
    # @param [Integer] status (200)
    def create_response(data, status = 200)
      body = JSON.generate(data, :ascii_only => true)
      headers = {
        'Content-Type'   => 'application/json; charset=UTF-8',
        'Content-Length' => body.bytesize.to_s,
      }
      return [ status, headers, [ body ] ]
    end
  end
end
