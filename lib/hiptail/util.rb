module HipTail
  module Util
    DEFAULT_VENDOR_NAME = "HipTail"
    DEFAULT_VENDOR_URL  = "https://github.com/dayflower/hiptail"

    # Build capability object.
    # @param [Hash] params
    # @option params [String] :key Identical key for add-on
    # @option params [String] :name Add-on name
    # @option params [String] :base_url Base URL for add-on
    # @option params [String] :capability_url URL for capability
    # @option params [String] :webhook_url URL for event webhook
    # @option params [String] :installed_url URL for installed / uninstalled event webhook
    # @option params [String] :description (same as :name) Add-on description (optional)
    # @option params [String] :vendor_name (same as :name) Vendor name (optional)
    # @option params [String] :vendor_url (same as :base_url) Vendor URL (optional)
    # @option params [String] :homepage_url (same as :base_url) Homepage (optional)
    # @option params [String] :sender_name (same as :name) Name of notification sender (optional)
    # @option params [String] :allow_global (true) Allow global installation (optional)
    # @option params [String] :allow_room (true) Allow room installation (optional)
    # @option params [String] :message_filter Room message filter regexp (optional)
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
          name: params[:vendor_name] || DEFAULT_VENDOR_NAME,
          url: (params[:vendor_url] || DEFAULT_VENDOR_URL).to_s,
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
        message_webhook[:pattern] = params[:message_filter].to_s
      end
      capability[:capabilities][:webhook] << message_webhook

      capability
    end
    module_function :create_capability
  end
end
