class AddRedirectUrlToPaymentAttempts < ActiveRecord::Migration[7.0]
  def change
    add_column :payment_attempts, :redirect_url, :text
  end
end
