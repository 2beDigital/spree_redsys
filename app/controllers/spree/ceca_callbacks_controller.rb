module Spree
  class CecaCallbacksController < Spree::BaseController

    skip_before_filter :verify_authenticity_token

    #ssl_required

    # Receive a direct notification from the gateway
    def ceca_notify
      raise 'Invalid params in ceca notification callback' unless params[:Num_operacion]
      @order ||= Spree::Order.find_by_number!('R'+params[:Num_operacion][0..8])
      notify_acknowledge = acknowledgeSignature(ceca_credentials(payment_method))
      if notify_acknowledge
        #TODO add source to payment
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
    def ceca_confirm
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      unless @order.state == "complete"
        order_upgrade()
        payment_upgrade(params, false)
      end
      # Unset the order id as it's completed.
      session[:order_id] = nil #deprecated from 2.3
      flash.notice = Spree.t(:order_processed_successfully)
      flash['order_completed'] = true
      redirect_to order_path(@order)
    end


    def ceca_credentials (payment_method)
      {
          :AcquirerBIN   => payment_method.preferred_AcquirerBIN,
          :MerchantID    => payment_method.preferred_MerchantID,
          :TerminalID    => payment_method.preferred_TerminalID,
          :secret_key    => payment_method.preferred_secret_key,
          :key_type      => payment_method.preferred_key_type
      }
    end

    def payment_upgrade (params, no_risky)
      payment = @order.payments.create!({:amount => @order.total,
                                         :payment_method => payment_method,
                                         :response_code => params[:Num_aut].to_s,
                                         :avs_response => params[:Referencia].to_s})

      payment.started_processing!
      @order.update(:considered_risky => 0) if no_risky
    end


    def payment_method
      @payment_method ||= Spree::PaymentMethod.find_by_type("Spree::BillingIntegration::cecaPayment")
    end

    def order_upgrade
      @order.update(:state => "complete", :considered_risky => 1,  :completed_at => Time.now)
      # Since we dont rely on state machine callback, we just explicitly call this method for spree_store_credits
      if @order.respond_to?(:consume_users_credit, true)
        @order.send(:consume_users_credit)
      end
      @order.finalize!
    end

    def acknowledgeSignature(credentials = nil)
      return false if (params[:TerminalID].blank? ||
          params[:TerminalID].to_s != "00000003")
      str =
          credentials[:secret_key] +
          params[:MerchantID].to_s +
              params[:AcquirerBIN].to_s +
              params[:TerminalID].to_s +
              params[:Num_operacion].to_s +
              params[:Importe].to_s +
              params[:TipoMoneda].to_s +
              params[:Exponente].to_s +
              params[:Referencia].to_s
      sig = Digest::SHA1.hexdigest(str)
      msg =
          "ceca_notify: Hour " +
              Time.now.to_s  +
          ", order_id: R" + params[:Num_operacion][0..8].to_s +
          "signature: " + sig.upcase + " ---- Ds_Signature " + params['Firma'].to_s
      logger.debug "#{msg}"
      sig.upcase == params[:Firma].to_s.upcase
    end


  end
end

