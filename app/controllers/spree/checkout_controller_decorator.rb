module Spree
  Spree::CheckoutController.class_eval do
    autoload :Helper, 'active_merchant/billing/integrations/redsys/helper.rb'

    before_filter :redirect_to_redsys_form_if_needed, :only => [:update]

    protected

    def redirect_to_redsys_form_if_needed
      return unless (params[:state] == "payment")
      return unless params[:order][:payments_attributes]

      if @order.update_attributes(object_params)
        if params[:order][:coupon_code] and !params[:order][:coupon_code].blank? and @order.coupon_code.present?
          fire_event('spree.checkout.coupon_code_added', :coupon_code => @order.coupon_code)
        end
      end

      load_order
      @payment_method = Spree::PaymentMethod.find(params[:order][:payments_attributes].first[:payment_method_id])

      @order.payments.destroy_all

      return unless @payment_method.kind_of?(Spree::BillingIntegration::RedsysPayment)

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
