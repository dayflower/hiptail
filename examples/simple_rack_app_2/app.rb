require 'hiptail'
require 'hiptail/authority/sqlite3_provider'
require 'sqlite3'

class SimpleAddon2 < HipTail::Web::RackApp
  def initialize
    super(
      :manager => setup_manager(),
      :key => "com.example.dayflower.simple2",
      :name => "Colorizer",
      :vendor_name => "dayflower",
      :message_filter => "(yellow|green|red|purple|gray)",
    )
  end

  private

  def setup_manager
    db = SQLite3::Database.new('hiptail.db')

    manager = HipTail::Manager.new(:authority_provider => HipTail::SQLite3AuthorityProvider.new(db))

    manager.on_room_message do |authority, event|
      message = event.message.message
      if message =~ %r{(yellow|green|red|purple|gray)}xm
        color = $1
      else
        color = 'random'
      end

      authority.send_notification(
        :room_id => event.room.id,
        :color => color,
        :message => message,
        :notify => true,
        :message_format => 'text',
      )
    end

    manager
  end
end
