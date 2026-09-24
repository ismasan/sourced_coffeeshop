# frozen_string_literal: true

# Read model tables written by the projectors in domain/.
Sequel.migration do
  change do
    create_table(:orders) do
      String :order_id, primary_key: true
      String :status, null: false
      String :payment_status, null: false
      String :customer_name
      String :items, null: false, text: true    # JSON: { item_id => { name, price, quantity, status } }
      String :members, null: false, text: true  # JSON: [username, ...]
      Integer :step, null: false, default: 0
      String :created_at
      String :updated_at
      index :status
    end

    create_table(:payments) do
      String :payment_id, primary_key: true
      String :order_id, null: false
      String :status, null: false
      Integer :amount, null: false, default: 0
      String :created_at
    end

    create_table(:deliverables) do
      String :order_id, primary_key: true
      String :customer_name
      String :ready_at, null: false
    end
  end
end
