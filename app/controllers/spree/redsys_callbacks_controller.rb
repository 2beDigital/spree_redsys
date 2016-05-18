module Spree
  class RedsysCallbacksController < Spree::BaseController

    skip_before_filter :verify_authenticity_token

    #ssl_required

    # Receive a direct notification from the gateway
    def redsys_notify
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      notify_acknowledge = acknowledgeSignature(redsys_credentials(payment_method))
      if notify_acknowledge
        unless @order.state == "complete"
          order_upgrade
        end
        payment_upgrade(params, true)
        @payment = Spree::Payment.find_by_order_id(@order)
        @payment.complete!
      else
        payment_upgrade(params, false)
      end
      render :nothing => true
    end


    # Handle the incoming user
    def redsys_confirm
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      unless @order.state == "complete"
        order_upgrade()
        payment_upgrade(params, false)
      end

      @current_order = nil
      flash.notice = Spree.t(:order_processed_successfully)
      flash['order_completed'] = true
      redirect_to order_path(@order)
    end


    def redsys_credentials (payment_method)
      {
          :terminal_id   => payment_method.preferred_terminal_id,
          :commercial_id => payment_method.preferred_commercial_id,
          :secret_key    => payment_method.preferred_secret_key,
          :key_type      => payment_method.preferred_key_type
      }
    end

    def payment_upgrade (params, no_risky)
			decodec = decode_Merchant_Parameters || Array.new
      payment = @order.payments.create!({:amount => @order.total,
                                         :payment_method => payment_method,
                                         :response_code => decodec.include?('Ds_Response')? decodec['Ds_Response'].to_s : nil,
                                         :avs_response => decodec.include?('Ds_AuthorisationCode')? decodec['Ds_AuthorisationCode'].to_s : nil})
      payment.started_processing!
      @order.update(:considered_risky => 0) if no_risky
    end

    def payment_method
      @payment_method ||= Spree::PaymentMethod.find(params[:payment_method_id])
      @payment_method ||= Spree::PaymentMethod.find_by_type("Spree::BillingIntegration::RedsysPayment")
    end

    def order_upgrade
      @order.update(:state => "complete", :considered_risky => 1,  :completed_at => Time.now)
      # Since we dont rely on state machine callback, we just explicitly call this method for spree_store_credits
      if @order.respond_to?(:consume_users_credit, true)
        @order.send(:consume_users_credit)
      end
      @order.finalize!
    end

    protected

    def decode_Merchant_Parameters
      return nil if(params[:Ds_MerchantParameters].blank?)
      jsonrec = Base64.urlsafe_decode64(params[:Ds_MerchantParameters])
      JSON.parse(jsonrec)
    end

    def create_MerchantSignature_Notif(key)
      keyDecoded=Base64.decode64(key)

      #obtenemos el orderId.
      orderrec = (decode_Merchant_Parameters['Ds_Order'].blank?)? decode_Merchant_Parameters['DS_ORDER'] : decode_Merchant_Parameters['Ds_Order']

      key3des=des3key(key, orderrec)
      hmac=hmac(key3des,params[:Ds_MerchantParameters])
      Base64.urlsafe_encode64(hmac)
    end


    def acknowledgeSignature(credentials = nil)
      return false if(params[:Ds_SignatureVersion].blank? ||
          params[:Ds_MerchantParameters].blank? ||
          params[:Ds_Signature].blank?)

      #HMAC_SHA256_V1
      return false if(params[:Ds_SignatureVersion] != credentials[:key_type])

      decodec = decode_Merchant_Parameters
			Rails.logger.debug "JSON Decodec: #{decodec}"
			
      create_Signature = create_MerchantSignature_Notif(credentials[:secret_key])
      msg =
          "REDSYS_NOTIFY: " +
					" ---- Ds_Response: " + decodec['Ds_Response'].to_s +					
          " ---- order_TS: " + decodec['Ds_Order'].to_s +
          " ---- order_Number: " + @order.number +
          " ---- Signature: " + create_Signature.to_s.upcase +
          " ---- Ds_Signature " + params[:Ds_Signature].to_s.upcase +
          " ---- RESULT " + ((create_Signature.to_s.upcase == params[:Ds_Signature].to_s.upcase)? 'OK' : 'KO')
      Rails.logger.info "#{msg}"
      res=create_Signature.to_s.upcase == params[:Ds_Signature].to_s.upcase
			
			responseCode=decodec['Ds_Response'].to_i
			Rails.logger.debug "Ds_ResponseInt: #{responseCode}"
			
			#Potser és una mica rebuscat, però comprovem primer la signature perquè si un señor
			#maligno envia una petició fake amb Ds_Response d'error, estariem denegant la compra
			#sense comprovar que la request és correcte.
			#Segons la doc, els codis OKs poden anar de 0000 a 0099 o 900 per a devolucions.
			return false if (responseCode > 99 && responseCode!=900)
			res
    end

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

