module Spree
  Spree::CheckoutController.class_eval do
    autoload :Helper, 'active_merchant/billing/integrations/redsys/helper.rb'

    before_filter :redirect_to_redsys_form_if_needed, :only => [:update]

    protected

    def redirect_to_redsys_form_if_needed
      return unless (params[:state] == "payment")
      return unless params[:order][:payments_attributes]

      load_order_with_lock
      @order.update_from_params(params, permitted_checkout_attributes, request.headers.env)
      @payment_method = Spree::PaymentMethod.find(params[:order][:payments_attributes].first[:payment_method_id])

      return unless @payment_method.kind_of?(Spree::BillingIntegration::RedsysPayment)
      
      @order.payments.destroy_all

      @payment_method.provider_class::Helper.credentials = redsys_credentials(@payment_method)

      render 'spree/shared/_redsys_payment_checkout', :layout => 'spree_redsys_application'

    end

    def redsys_credentials (payment_method)
      {
          :terminal_id   => payment_method.preferred_terminal_id,
          :commercial_id => payment_method.preferred_commercial_id,
          :secret_key    => payment_method.preferred_secret_key,
          :key_type      => payment_method.preferred_key_type
      }
    end


  end

end
