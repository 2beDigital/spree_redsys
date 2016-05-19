require "spree_core"
require "spree_api"
require "spree_backend"
require "spree_frontend"


require "spree_redsys/engine"
require "spree_redsys/version"

module ActiveMerchant
  module Billing
    module Integrations
      autoload :Redsys, 'active_merchant/billing/integrations/redsys'
    end
  end
end
