module Spree
  class SermepaCallbacksController < Spree::BaseController
    include ActiveMerchant::Billing::Integrations

    skip_before_filter :verify_authenticity_token

    ssl_required

    # Receive a direct notification from the gateway
    def sermepa_notify
      notify = ActiveMerchant::Billing::Integrations::Sermepa.notification(request.query_parameters)
      @order ||= Spree::Order.find_by_number! (params[:order_id])
      notify_acknowledge = notify.acknowledge(sermepa_credentials(payment_method))
      logger.info 'notify_acknowledge :' + notify_acknowledge.to_s
      if notify_acknowledge
        #TODO add source to payment
        unless @order.state == "complete"
          @order.payments.destroy_all
          order_upgrade
          payment_upgrade
        end
        @payment = Spree::Payment.find_by_order_id(@order)
        logger.info 'notify.complete? :' + notify.complete?.to_s
        @payment.complete! if notify.complete?
      else
        @order.payments.destroy_all
        @payment = @order.payments.create({:amount => @order.total,
                                          :source_type => 'Spree:SermepaCreditCard',
                                          :payment_method => payment_method,
                                          :state => 'processing',
                                          :response_code => notify.error_code,
                                          :avs_response => notify.error_message[0..255]},
                                          :without_protection => true)
      end

      render :nothing => true

    end


    def sermepa_credentials (payment_method)
      {
          :terminal_id   => payment_method.preferred_terminal_id,
          :commercial_id => payment_method.preferred_commercial_id,
          :secret_key    => payment_method.preferred_secret_key,
          :key_type      => payment_method.preferred_key_type
      }
    end

    def payment_upgrade
      #payment_method = Spree::PaymentMethod.find_by_type("Spree::BillingIntegration::SermepaPayment")
      payment = @order.payments.create({:amount => @order.total,
                                        :source_type => 'Spree:SermepaCreditCard',
                                        :payment_method => payment_method },
                                       :without_protection => true)
      payment.started_processing!
      payment.pend!
    end

    # create the gateway from the supplied options
    def payment_method
      @payment_method ||= Spree::PaymentMethod.find(params[:payment_method_id])
      @payment_method ||= Spree::PaymentMethod.find_by_type("Spree::BillingIntegration::SermepaPayment")
    end



    def order_upgrade
      ## TODO refactor coz u don't need really @order.state = "payment"
      @order.state = "payment"
      @order.save

      @order.update_attributes({:state => "complete", :completed_at => Time.now}, :without_protection => true)

      state_callback(:after) # So that after_complete is called, setting session[:order_id] to nil

      # Since we dont rely on state machine callback, we just explicitly call this method for spree_store_credits
      if @order.respond_to?(:consume_users_credit, true)
        @order.send(:consume_users_credit)
      end

      @order.finalize!
    end

  end
end

