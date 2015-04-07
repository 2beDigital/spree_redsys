module Spree
  Spree::CheckoutController.class_eval do
    before_filter :redirect_to_sermepa_form_if_needed, :only => [:update]

    protected

    def redirect_to_sermepa_form_if_needed
      return unless (params[:state] == "payment")
      return unless params[:order][:payments_attributes]

      load_order_with_lock
      @order.update_from_params(params, permitted_checkout_attributes, request.headers.env)
      @payment_method = Spree::PaymentMethod.find(params[:order][:payments_attributes].first[:payment_method_id])

      ## Fixing double payment creation ##
      if @payment_method.kind_of?(Spree::PaymentMethod::Check) ||
         @payment_method.kind_of?(Spree::BillingIntegration::SermepaPayment) ||
         @payment_method.kind_of?(Spree::BillingIntegration::CecaPayment)
         @order.payments.destroy_all
      end

      if @payment_method.kind_of?(Spree::BillingIntegration::SermepaPayment)

        @payment_method.provider_class::Helper.credentials = sermepa_credentials(@payment_method)
        #set_cache_buster
        render 'spree/shared/_sermepa_payment_checkout', :layout => 'spree_sermepa_application'
      else if @payment_method.kind_of?(Spree::BillingIntegration::CecaPayment)

            @payment_method.provider_class::Helper.credentials = ceca_credentials(@payment_method)

            render 'spree/shared/_ceca_payment_checkout', :layout => 'spree_sermepa_application'
          end
      end
    end

    def sermepa_credentials (payment_method)
      {
          :terminal_id   => payment_method.preferred_terminal_id,
          :commercial_id => payment_method.preferred_commercial_id,
          :secret_key    => payment_method.preferred_secret_key,
          :key_type      => payment_method.preferred_key_type
      }
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

  end

end
