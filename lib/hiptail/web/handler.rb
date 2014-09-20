require 'json'
require 'uri'
require 'hiptail/util'

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

      capability = HipTail::Util::create_capability(params)
      create_response(capability)
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
