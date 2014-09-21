module HipTail
  # @abstract
  class AuthorityProvider
    # @param [String] oauth_id
    # @return [HipTail::Authority]
    def [](oauth_id)
      get(oauth_id)
    end

    # @param [String] oauth_id
    # @param [HipTail::Authority] authority
    # @return [HipTail::Authority]
    def []=(oauth_id, authority)
      register(oauth_id, authority)
    end

    # @abstract
    # @param [String] oauth_id
    # @return [HipTail::Authority]
    def get(oauth_id)
      raise
    end

    # @abstract
    # @param [String] oauth_id
    # @param [HipTail::Authority] authority
    # @return [HipTail::Authority]
    def register(oauth_id, authority)
      raise
    end

    # @abstract
    # @param [String] oauth_id
    # @return [void]
    def unregister(oauth_id)
      raise
    end
  end

  class MemoryAuthorityProvider < AuthorityProvider
    # @return [HipTail::MemoryAuthorityProvider]
    def initialize
      @authorities = {}
    end

    # @param [String] oauth_id
    # @return [HipTail::Authority]
    def get(oauth_id)
      @authorities[oauth_id]
    end

    # @param [String] oauth_id
    # @param [HipTail::Authority] authority
    # @return [HipTail::Authority]
    def register(oauth_id, authority)
      @authorities[oauth_id] = authority
    end

    # @param [String] oauth_id
    # @return [void]
    def unregister(oauth_id)
      @authorities.delete(oauth_id)
    end
  end
end
