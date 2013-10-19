module Spree
  module Admin
    class ManualOrderUpgradeController < Spree::BaseController

      def process(block)
        order_state = params[:state_to]
        mail_order_confirmation = params[:mail_order_confirmation]

        order = Spree::Order.find_by_number(params[:order_id])
        state = order_state || order.checkout_steps.first

        if order_state.present? && order_state == order.checkout_steps.last
          order.update_attributes({:state => state, :completed_at => Time.now, :shipment_state => 'ready', :payment_state => 'paid'}, :without_protection => true)
        else
          order.update_attributes({:state => state, :completed_at => nil, :shipment_state => nil, :payment_state => 'balance_due'}, :without_protection => true)
        end

        # Since we dont rely on state machine callback, we just explicitly call this method for spree_store_credits
        if order.respond_to?(:consume_users_credit, true)
          order.send(:consume_users_credit)
        end

        order.deliver_order_confirmation_email if mail_order_confirmation

        redirect_to :controller => 'admin/orders', :action => 'index'

      end


    end
  end
end
