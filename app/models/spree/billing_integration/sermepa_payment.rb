  class Spree::BillingIntegration::SermepaPayment < Spree::BillingIntegration
    preference :commercial_id, :string
    preference :terminal_id, :integer, :default => 1
    preference :currency, :string, :default => 'EUR'
    preference :secret_key, :string
    preference :key_type, :string, :default => 'sha1_extended' #sabadell is sha1_extended but can be sha1_complete
    preference :notify_alternative_domain_url, :string #This can allow us cloudflare integration

    attr_accessible :preferred_commercial_id, :preferred_terminal_id, :preferred_currency,
                    :preferred_secret_key, :preferred_key_type, :preferred_server, :preferred_test_mode, :preferred_notify_alternative_domain_url

    def provider_class
      ActiveMerchant::Billing::Integrations::Sermepa
    end

    def payment_profiles_supported?
      false
    end

    def capture(payment_or_amount, account_or_response_code, gateway_options)
      if payment_or_amount.is_a?(Spree::Payment)
        authorization = find_authorization(payment_or_amount)
        provider.capture(amount_in_cents(payment_or_amount.amount), authorization.params["transaction_id"], :currency => preferred_currency)
      else
        provider.capture(payment_or_amount, account_or_response_code, :currency => preferred_currency)
      end
    end

    def credit(*args)
      amount = args.shift
      response_code = args.first.is_a?(String) ? args.first : args[1]
      provider.credit(amount, response_code, :currency => preferred_currency)
    end

    def find_authorization(payment)
      logs = payment.log_entries.all(:order => 'created_at DESC')
      logs.each do |log|
        details = YAML.load(log.details) # return the transaction details
        if (details.params['payment_status'] == 'Pending' && details.params['pending_reason'] == 'authorization')
          return details
        end
      end
      return nil
    end

    def find_capture(payment)
      #find the transaction associated with the original authorization/capture
      logs = payment.log_entries.all(:order => 'created_at DESC')
      logs.each do |log|
        details = YAML.load(log.details) # return the transaction details
        if details.params['payment_status'] == 'Completed'
          return details
        end
      end
      return nil
    end

    def amount_in_cents(amount)
      (100 * amount).to_i
    end

  end