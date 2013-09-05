module Spree
  class CecaCallbacksController < Spree::BaseController

    skip_before_filter :verify_authenticity_token

    ssl_required

    # Receive a direct notification from the gateway
    def ceca_notify
      raise 'Invalid params in ceca notification callback' unless params[:Num_operacion]
      @order ||= Spree::Order.find_by_number!('R'+params[:Num_operacion][0..8])
      notify_acknowledge = acknowledgeSignature(ceca_credentials(payment_method))
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
    def ceca_confirm
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      # Unset the order id as it's completed.
      session[:order_id] = nil
      flash[:notice] = I18n.t(:order_processed_successfully)
      flash[:commerce_tracking] = "true"
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

    def payment_upgrade (params)
      payment = @order.payments.create({:amount => @order.total,
                                        :source_type => 'Spree:cecaCreditCard',
                                        :payment_method => payment_method,
                                        :response_code => params['Num_aut'].to_s,
                                        :avs_response => params['COD_AUT'].to_s},
                                        :without_protection => true)
      payment.started_processing!
    end


    def payment_method
      @payment_method ||= Spree::PaymentMethod.find_by_type("Spree::BillingIntegration::cecaPayment")
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
      return false if (params['TerminalID'].blank? ||
          params['TerminalID'].to_s != "00000003")
      str =
          credentials[:secret_key] +
          params['MerchantID'].to_s +
              params['AcquirerBIN'].to_s +
              params['TerminalID'].to_s +
              params['Num_operacion'].to_s +
              params['Importe'].to_s +
              params['TipoMoneda+'].to_s +
              params['Exponente'].to_s +
              params['Referencia'].to_s
      sig = Digest::SHA1.hexdigest(str)
      msg =
          "ceca_notify: Hour " +
              Time.now.to_s  +
          ", order_id: R" + params[:Num_operacion][0..8].to_s +
          "signature: " + sig.upcase + " ---- Ds_Signature " + params['Firma'].to_s
      logger.debug "#{msg}"
      sig.upcase == params['Firma'].to_s.upcase
    end


  end
end

