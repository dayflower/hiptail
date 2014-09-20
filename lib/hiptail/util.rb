module HipTail
  module Util
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
    module_function :create_capability
  end
end
