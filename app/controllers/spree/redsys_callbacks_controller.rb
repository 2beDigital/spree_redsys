module Spree
  class RedsysCallbacksController < Spree::BaseController
    include ActiveMerchant::Billing::Integrations

    skip_before_filter :verify_authenticity_token

    #ssl_required

    # Receive a direct notification from the gateway
    def redsys_notify
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      notify = ActiveMerchant::Billing::Integrations::Redsys.notification(params)
      Rails.logger.info "parameters --------------  #{params.inspect}"
      #Rails.logger.info "body --------------  #{request.body.read.inspect}"
      if notify.acknowledge(redsys_credentials(payment_method)) && notify.complete?
        unless @order.complete?
          order_upgrade
        end
        @payment = payment_upgrade(params, true)
        @payment.complete!
      else
        @payment = payment_upgrade(params, false)
      end
      render :nothing => true
    end


    # Handle the incoming user
    def redsys_confirm
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      unless @order.complete?
        order_upgrade()
        payment_upgrade(params, false)
      end

      @current_order = session[:order_id] = nil
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
      notify = ActiveMerchant::Billing::Integrations::Redsys.notification(params)
			decodec = notify.decode_Merchant_Parameters || Array.new
      payment = @order.payments.create!({:amount => @order.total,
                                         :payment_method => payment_method,
                                         :response_code => decodec.include?('Ds_Response')? decodec['Ds_Response'].to_s : nil,
                                         :avs_response => decodec.include?('Ds_AuthorisationCode')? decodec['Ds_AuthorisationCode'].to_s : nil})
      payment.started_processing!
      @order.approve! if no_risky
      return payment
    end

    def payment_method
      @payment_method ||= Spree::PaymentMethod.find(params[:payment_method_id])
      @payment_method ||= Spree::PaymentMethod.find_by_type("Spree::BillingIntegration::RedsysPayment")
    end

    def order_upgrade
      @order.update(:state => "complete", :completed_at => Time.now)
      @order.considered_risky!

      # Since we dont rely on state machine callback, we just explicitly call this method for spree_store_credits
      if @order.respond_to?(:consume_users_credit, true)
        @order.send(:consume_users_credit)
      end
      @order.finalize!
    end





  end
end

