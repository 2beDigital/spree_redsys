# encoding: utf-8
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Redsys
        # Redsys/Servired Spanish Virtual POS Gateway
        #
        # Support for the Spanish payment gateway provided by Redsys, part of Servired,
        # one of the main providers in Spain to Banks and Cajas.
        #
        # Requires the :terminal_id, :commercial_id, and :secret_key to be set in the credentials
        # before the helper can be used. Credentials may be overwriten when instantiating the helper
        # if required or instead of the global variable. Optionally, the :key_type can also be set to 
        # either 'sha1_complete' or 'sha1_extended', where the later is the default case. This
        # is a configurable option in the Redsys admin which you may or may not be able to access.
        # If nothing seems to work, try changing this.
        #
        # Ensure the gateway is configured correctly. Synchronization should be set to Asynchronous
        # and the parameters in URL option (Parámetros en las URLs) should be set to true unless
        # the notify_url is provided. During development on localhost ensuring this option is set
        # is especially important as there is no other way to confirm a successful purchase.
        #
        # Your view for a payment form might look something like the following:
        #
        #<%= payment_service_for order_number, Spree::Config[:site_name],
        #    :amount => (@payment_method.amount_in_cents(@order.total)),
        #    :currency => @payment_method.preferred_currency,
        #    :description => items.to_s[0..120].gsub(/({|")/,'').gsub(/}/,"\n").gsub("=>",": ").gsub("[","(").gsub("]",")"),
        #    :account_name => "#{@order.ship_address.firstname} #{@order.ship_address.lastname}",
        #    :country => @payment_method.provider_class.language_code(I18n.locale),
        #    :return_url => edit_order_checkout_url(@order, :state => 'payment'),
        #    :forward_url => redsys_confirm_order_redsys_callbacks_url(@order, :payment_method_id => @payment_method),
        #    :notify_url => notify_url_redsys,
        #    :service => :redsys do |service| %>
        #    
        #     <%= submit_tag "PAY!" %>
        #     <% service.signature_version @payment_method.preferred_key_type %>
        #   <% end %>
        #
        # HMAC SHA256 Redsys
        #
        # 
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include PostsData

          class << self
            # Credentials should be set as a hash containing the fields:
            #  :terminal_id, :commercial_id, :secret_key, :key_type (optional)
            attr_accessor :credentials
            attr_reader :redsysparams
          end

          ############# HMAC_SHA256_V1 ############

          mapping :signature_version, 'Ds_SignatureVersion'

          mapping :merchant_parameters, 'Ds_MerchantParameters'

          mapping :signature_256, 'Ds_Signature'

          # ammount should always be provided in cents!
          def initialize(order, account, options = {})
            self.credentials = options.delete(:credentials) if options[:credentials]
            super(order, account, options)
            @redsysparams = {
                :Ds_Merchant_Order => order,
                :Ds_Merchant_MerchantName => account,
                :Ds_Merchant_Amount => options[:amount],
                :Ds_Merchant_Currency => Redsys.currency_code(options[:currency]),
                :Ds_Merchant_MerchantCode => credentials[:commercial_id],
                :Ds_Merchant_Terminal => credentials[:terminal_id],
                :Ds_Merchant_TransactionType => Redsys.transaction_code(:authorization), # Default Transaction Type
                :Ds_Merchant_ProductDescription => options[:description],
                :Ds_Merchant_Titular => options[:account_name],
                :Ds_Merchant_ConsumerLanguage => Redsys.language_code(options[:country]),
                :Ds_Merchant_UrlKO => options[:return_url],
                :Ds_Merchant_UrlOK => options[:forward_url],
                :Ds_Merchant_MerchantURL => options[:notify_url]
            }
          end


          ############# Traditional ############

          # Allow credentials to be overwritten if needed
          def credentials
            @credentials || self.class.credentials
          end
          def credentials=(creds)
            @credentials = (self.class.credentials || {}).dup.merge(creds)
          end

          def form_fields
            add_field mappings[:merchant_parameters], create_Merchant_Parameters
            add_field mappings[:signature_256], create_Merchant_Signature
            @fields
          end

          def create_Merchant_Parameters
            Base64.strict_encode64(@redsysparams.to_json)
          end


          # Generate a signature authenticating the current request.
          def create_Merchant_Signature
            key = credentials[:secret_key]
            key3des=des3key(key,@redsysparams[:Ds_Merchant_Order])
            hmac=hmac(key3des,create_Merchant_Parameters)
            Base64.strict_encode64(hmac)
          end

          protected

          def des3key(key,message)
            block_length = 8
            cipher = OpenSSL::Cipher::Cipher.new('DES3')
            cipher.encrypt

            cipher.key = Base64.strict_decode64(key)
            # The OpenSSL default of an all-zeroes ("\\0") IV is used.
            cipher.padding = 0

            message += "\0" until message.bytesize % block_length == 0 # Pad with zeros

            output = cipher.update(message) + cipher.final
            output
          end

          def hmac(key,message)
            OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, message)
          end

        end
      end
    end
  end
end
