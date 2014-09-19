module HipTail
  class AuthorityProvider
    def [](oauth_id)
      get(oauth_id)
    end

    def []=(oauth_id, authority)
      register(oauth_id, authority)
    end

    def get(oauth_id)
      raise
    end

    def register(oauth_id, authority)
      raise
    end

    def unregister(oauth_id)
      raise
    end
  end

  class MemoryAuthorityProvider < AuthorityProvider
    def initialize
      @authorities = {}
    end

    def get(oauth_id)
      @authorities[oauth_id]
    end

    def register(oauth_id, authority)
      @authorities[oauth_id] = authority
    end

    def unregister(oauth_id)
      @authorities.delete(oauth_id)
    end
  end
end
