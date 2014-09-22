require 'sinatra'
require 'hiptail'
require 'hiptail/authority/sqlite3_provider'
require 'sqlite3'

db = SQLite3::Database.new('hiptail.db')

manager = HipTail::Manager.new(:authority_provider => HipTail::SQLite3AuthorityProvider.new(db))

manager.on_room_message do |event|
  message = event.message.message
  if message =~ %r{(yellow|green|red|purple|gray)}xm
    color = $1
  else
    color = 'random'
  end

  event.authority.send_notification(
    :room_id => event.room.id,
    :color => color,
    :message => message,
    :notify => true,
    :message_format => 'text',
  )
end

handler = HipTail::Web::Handler.new(manager)

get '/' do
  'Hello, World!'
end

get '/cap' do
  capability_params = {
    :key             => "com.example.hiptail.sinatra",
    :name            => "Colorizer",
    :vendor_name     => "hiptail",
    :message_filter  => "(yellow|green|red|purple|gray)",
    :base_path       => "/",
    :capability_path => "/cap",
    :webhook_path    => "/event",
    :installed_path  => "/install",
  }

  handler.handle_capability(request, capability_params)
end

post '/install' do
  handler.handle_install(request)
end

delete '/install/:oauth_id' do
  handler.handle_uninstall(request, params[:oauth_id])
end

post '/event' do
  handler.handle_event(request)
end
