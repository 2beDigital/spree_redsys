module Spree
  class RedsysCallbacksController < Spree::BaseController

    skip_before_filter :verify_authenticity_token

    #ssl_required

    # Receive a direct notification from the gateway
    def redsys_notify
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      notify_acknowledge = acknowledgeSignature(redsys_credentials(payment_method))
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
    def redsys_confirm
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


    def redsys_credentials (payment_method)
      {
          :terminal_id   => payment_method.preferred_terminal_id,
          :commercial_id => payment_method.preferred_commercial_id,
          :secret_key    => payment_method.preferred_secret_key,
          :key_type      => payment_method.preferred_key_type
      }
    end

    def payment_upgrade (params, no_risky)
      payment = @order.payments.create!({:amount => @order.total,
                                        :payment_method => payment_method,
                                        :response_code => params['Ds_Response'].to_s,
                                        :avs_response => params['Ds_AuthorisationCode'].to_s})
      payment.started_processing!
      @order.update(:considered_risky => 0) if no_risky
    end


    def payment_method
      @payment_method ||= Spree::PaymentMethod.find(params[:payment_method_id])
      @payment_method ||= Spree::PaymentMethod.find_by_type("Spree::BillingIntegration::redsysPayment")
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
      return false if (params['Ds_Response'].blank? ||
          params['Ds_Response'].to_s != "0000")
      str =
          params['Ds_Amount'].to_s +
              params['Ds_Order'].to_s +
              params['Ds_MerchantCode'].to_s +
              params['Ds_Currency'].to_s +
              params['Ds_Response'].to_s
      str += credentials[:secret_key]
      sig = Digest::SHA1.hexdigest(str)
      msg =
          "redsys_notify: Hour " +
          params['Ds_Hour'].to_s  +
          ", order_id: " + params[:order_id].to_s +
          "signature: " + sig.upcase + " ---- Ds_Signature " + params['Ds_Signature'].to_s
      logger.debug "#{msg}"
      sig.upcase == params['Ds_Signature'].to_s.upcase
    end


  end
end

