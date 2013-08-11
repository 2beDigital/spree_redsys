module Spree
  class SermepaCallbacksController < Spree::BaseController

    skip_before_filter :verify_authenticity_token

    ssl_required

    # Receive a direct notification from the gateway
    def sermepa_notify
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      notify_acknowledge = acknowledgeSignature(sermepa_credentials(payment_method))
      if notify_acknowledge
        #TODO add source to payment
        unless @order.state == "complete"
          @order.payments.destroy_all
          order_upgrade
          payment_upgrade(params)
        end
        @payment = Spree::Payment.find_by_order_id(@order)
        @payment.complete!
      else
        @order.payments.destroy_all
        @payment = payment_upgrade(params)
      end
      render :nothing => true
    end


    # Handle the incoming user
    def sermepa_confirm
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      # Unset the order id as it's completed.
      session[:order_id] = nil
      flash[:notice] = I18n.t(:order_processed_successfully)
      flash[:commerce_tracking] = "true"
      redirect_to order_path(@order)
    end


    def sermepa_credentials (payment_method)
      {
          :terminal_id   => payment_method.preferred_terminal_id,
          :commercial_id => payment_method.preferred_commercial_id,
          :secret_key    => payment_method.preferred_secret_key,
          :key_type      => payment_method.preferred_key_type
      }
    end

    def payment_upgrade (params)
      payment = @order.payments.create({:amount => @order.total,
                                        :source_type => 'Spree:SermepaCreditCard',
                                        :payment_method => payment_method,
                                        :response_code => params['Ds_Response'].to_s,
                                        :avs_response => params['Ds_AuthorisationCode'].to_s},
                                        :without_protection => true)
      payment.started_processing!
    end


    def payment_method
      @payment_method ||= Spree::PaymentMethod.find(params[:payment_method_id])
      @payment_method ||= Spree::PaymentMethod.find_by_type("Spree::BillingIntegration::SermepaPayment")
    end

    def order_upgrade
      ## TODO refactor coz u don't need really @order.state = "payment"
      @order.state = "payment"
      @order.save

      @order.update_attributes({:state => "complete", :completed_at => Time.now}, :without_protection => true)

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
          "sermepa_notify: Hour " +
          params['Ds_Hour'].to_s  +
          ", order_id: " + params[:order_id].to_s +
          "signature: " + sig.upcase + " ---- Ds_Signature " + params['Ds_Signature'].to_s
      logger.debug "#{msg}"
      sig.upcase == params['Ds_Signature'].to_s.upcase
    end


  end
end

