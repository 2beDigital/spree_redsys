class CreateSpreeBillingIntegrationSermepaPayments < ActiveRecord::Migration
  def change
    create_table :spree_billing_integration_sermepa_payments do |t|

      t.timestamps
    end
  end
end
