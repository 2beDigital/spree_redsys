class Spree::BillingIntegration::RedsysPayment < Spree::BillingIntegration
  preference :commercial_id, :string
  preference :terminal_id, :integer, :default => 1
  preference :currency, :string, :default => 'EUR'
  preference :secret_key, :string
  preference :key_type, :string, :default => 'HMAC_SHA256_V1'
  preference :notify_alternative_domain_url, :string #This can allow us cloudflare integration

  def provider_class
    ActiveMerchant::Billing::Integrations::Redsys
  end


  def actions
    %w{capture void}
  end

  # Indicates whether its possible to capture the payment
  def can_capture?(payment)
    ['checkout', 'pending', 'processing'].include?(payment.state)
  end

  # Indicates whether its possible to void the payment.
  def can_void?(payment)
    payment.state != 'void'
  end

  def capture(*args)
    ActiveMerchant::Billing::Response.new(true, "", {}, {})
  end

  def cancel(response); end

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