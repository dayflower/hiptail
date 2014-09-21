require 'bundler/setup'
require 'rack'
require 'hiptail'
require 'hiptail/authority/sqlite3_provider'
require 'sqlite3'

db = SQLite3::Database.new('hiptail.db')

manager = HipTail::Manager.new(:authority_provider => HipTail::SQLite3AuthorityProvider.new(db))

manager.on_install do |authority|
  if authority.global?
    authority.get_all_rooms.rooms.each do |room|
      authority.send_notification(
        :room_id => room.id,
        :message => "Installed.",
        :notify => false,
        :message_format => 'text',
      )
    end
  else
    authority.send_notification(
      :room_id => authority.room_id,
      :message => "Installed.",
      :notify => false,
      :message_format => 'text',
    )
  end
end

manager.on_room_message do |authority, event|
  authority.send_notification(
    :room_id => event.room.id,
    :color => 'green',
    :message => event.message.message.reverse,
    :notify => true,
    :message_format => 'text',
  )
end

manager.on_room_enter do |authority, event|
  authority.send_notification(
    :room_id => event.room.id,
    :color => 'red',
    :message => "Welcome, @#{event.sender.mention_name}!",
    :notify => true,
    :message_format => "text",
  )
end

run HipTail::Web::RackApp.new(
  :manager => manager,
  :key => "com.example.hiptail.simple1",
  :name => "Mr. Reverse",
  :vendor_name => "hiptail",
)
