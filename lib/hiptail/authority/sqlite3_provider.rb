require 'hiptail/authority/provider'
require 'sqlite3'

class HipTail::SQLite3AuthorityProvider < HipTail::AuthorityProvider
  # @return [HipTail::SQLite3AuthorityProvider]
  def initialize(db)
    @authorities = {}
    @db = db

    build
  end

  # @return [void]
  def build
    @db.execute_batch <<-'END_SQL'
      CREATE TABLE IF NOT EXISTS hiptail_authority (
          oauth_id          VARCHAR(255) NOT NULL PRIMARY KEY,
          oauth_secret      VARCHAR(255) NOT NULL,
          authorization_url VARCHAR(255) NOT NULL,
          token_url         VARCHAR(255) NOT NULL,
          room_id           INT UNSIGNED,
          group_id          INT UNSIGNED NOT NULL,
          api_base          VARCHAR(255) NOT NULL,
          created_at        INTEGER NOT NULL
      );
    END_SQL
  end

  SQL_GET = <<-'END_SQL'
    SELECT * FROM hiptail_authority WHERE oauth_id = ? LIMIT 1
  END_SQL

  # @abstract
  # @param [String] oauth_id
  # @return [HipTail::Authority]
  def get(oauth_id)
    unless @authorities.include?(oauth_id)
      begin
        last_rah = @db.results_as_hash
        @db.results_as_hash = true
        @db.execute(SQL_GET, oauth_id) do |row|
          data = row.to_a.select { |f| f[0].is_a?(String) }.map { |f| [ f[0].to_sym, f[1] ] }
          @authorities[oauth_id] = HipTail::Authority.new(Hash[*data.flatten(1)])
          break
        end
      ensure
        @db.results_as_hash = last_rah
      end
    end

    @authorities[oauth_id]
  end

  SQL_REGISTER = <<-'END_SQL'
    REPLACE INTO hiptail_authority
      ( oauth_id, oauth_secret, authorization_url, token_url, room_id, group_id, api_base, created_at )
      VALUES ( :oauth_id, :oauth_secret, :authorization_url, :token_url, :room_id, :group_id, :api_base, :created_at )
  END_SQL

  # @param [String] oauth_id
  # @param [HipTail::Authority] authority
  # @return [HipTail::Authority]
  def register(oauth_id, authority)
    @authorities[oauth_id] = authority

    row_data = authority.as_hash
    [ :api_base, :authorization_url, :token_url ].each do |key|
      row_data[key] = row_data[key].to_s
    end
    row_data[:created_at] = Time.now.to_i
    @db.execute(SQL_REGISTER, row_data)
  end

  SQL_UNREGISTER = <<-'END_SQL'
    DELETE FROM hiptail_authority WHERE oauth_id = ?
  END_SQL

  # @param [String] oauth_id
  # @return [void]
  def unregister(oauth_id)
    @authorities.delete(oauth_id)

    @db.execute(SQL_UNREGISTER, oauth_id)
  end
end
