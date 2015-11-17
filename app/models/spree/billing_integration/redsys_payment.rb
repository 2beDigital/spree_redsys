  class Spree::BillingIntegration::RedsysPayment < Spree::BillingIntegration
    preference :commercial_id, :string
    preference :terminal_id, :integer, :default => 1
    preference :currency, :string, :default => 'EUR'
    preference :secret_key, :string
    preference :key_type, :string, :default => 'HMAC_SHA256_V1'
    preference :notify_alternative_domain_url, :string #This can allow us cloudflare integration

    attr_accessible :preferred_commercial_id, :preferred_terminal_id, :preferred_currency,
                    :preferred_secret_key, :preferred_key_type, :preferred_notify_alternative_domain_url,
                    :preferred_server, :preferred_test_mode


    def provider_class
      ActiveMerchant::Billing::Integrations::Redsys
    end

    def actions
      %w{capture void}
    end

    # Indicates whether its possible to capture the payment
    def can_capture?(payment)
      ['checkout', 'pending'].include?(payment.state)
    end

    # Indicates whether its possible to void the payment.
    def can_void?(payment)
      payment.state != 'void'
    end

    def capture(*args)
      ActiveMerchant::Billing::Response.new(true, "", {}, {})
    end

    def void(*args)
      ActiveMerchant::Billing::Response.new(true, "", {}, {})
    end

    def source_required?
      false
    end

    def amount_in_cents(amount)
      (100 * amount).to_i
    end

  end