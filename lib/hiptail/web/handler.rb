require 'json'
require 'uri'

module HipTail
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

      body.gsub!(/[\u{007f}-\u{10ffff}]+/) { |match| match.unpack("U*").map! { |i| "\\u#{i.to_s(16)}" }.join }

      headers = {
        'Content-Type'   => 'application/json; charset=UTF-8',
        'Content-Length' => body.bytesize.to_s,
      }
      return [ status, headers, [ body ] ]
    end
  end
end
