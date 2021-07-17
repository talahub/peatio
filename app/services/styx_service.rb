class Styx
    include HTTParty
    base_uri 'styx.dev.tiki.services'
  
    def user(user_id)
      self.class.get("/v1/customers/" + user_id)
    end
  end