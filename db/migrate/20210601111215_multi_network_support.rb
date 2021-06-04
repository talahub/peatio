class MultiNetworkSupport < ActiveRecord::Migration[5.2]
  def up
    # Add blockchain_currencies table
    create_table :blockchain_currencies do |t|
      t.string :currency_id, foreign_key: true, class: 'Currency', null: false
      t.string :blockchain_key, foreign_key: true, null: true, class: 'Blockchain'
      t.decimal :deposit_fee, precision: 32, scale: 16, default: 0, null: false
      t.decimal :min_deposit_amount, precision: 32, scale: 16, default: 0, null: false
      t.decimal :min_collection_amount, precision: 32, scale: 16, default: 0, null: false
      t.decimal :withdraw_fee, precision: 32, scale: 16, default: 0, null: false
      t.decimal :min_withdraw_amount, precision: 32, scale: 16, default: 0, null: false
      t.decimal :withdraw_limit_24h, precision: 32, scale: 16, default: 0, null: false
      t.decimal :withdraw_limit_72h, precision: 32, scale: 16, default: 0, null: false
      t.boolean :deposit_enabled, default: true, null: false
      t.boolean :withdrawal_enabled, default: true, null: false
      t.bigint :base_factor, default: 1, null: false
      t.string :status, limit: 32, null: false, default: 'enabled'
      t.json :options
      t.timestamps
    end

    # Add blockchain key to deposits/withdraws/payment_addresses/beneficiaries tables
    %i[deposits withdraws beneficiaries].each do |t|
      add_column t, :blockchain_key, :string, null: true, after: :currency_id
    end

    # TODO
    # deposit.spread / transaction

    # Update all coin beneficiaries with blockchain_key
    Beneficiary.find_each(batch_size: 100) do |beneficiary|
      beneficiary.update(blockchain_key: beneficiary.currency.blockchain_key)
    end

    # Update all pending coin deposits with blockchain_key by wallet
    Deposit.find_each(batch_size: 100) do |deposit|
      deposit.update(blockchain_key: deposit.currency.blockchain_key)
    end

    # Update all pending coin withdraws with blockchain_key by wallet
    Withdraw.find_each(batch_size: 100) do |withdraw|
      withdraw.update(blockchain_key: withdraw.currency.blockchain_key)
    end

    add_column :payment_addresses, :blockchain_key, :string, after: :wallet_id
    # Update all payment address with blockchain_key by wallet
    PaymentAddress.find_each(batch_size: 100) do |payment_address|
      payment.update(blockchain_key: payment_address.wallet.blockchain_key)
    end

    # Move currencies configs to blockchain currency
    Currency.find_each(batch_size: 10) do |currency|
      BlockchainCurrency.create(
        currency_id: currency.id,
        blockchain_key: currency.blockchain_key,
        deposit_fee: currency.deposit_fee,
        min_deposit_amount: currency.min_deposit_amount,
        min_collection_amount: currency.min_collection_amount,
        withdraw_fee: currency.withdraw_fee,
        min_withdraw_amount: currency.min_withdraw_amount,
        withdraw_limit_24h: currency.withdraw_limit_24h,
        withdraw_limit_72h: currency.withdraw_limit_72h,
        deposit_enabled: currency.deposit_enabled,
        withdrawal_enabled: currency.withdrawal_enabled,
        base_factor: currency.base_factor,
        status: currency.status,
        options: currency.options
      )
    end

    # Remove redundant currencies fields
    ActiveRecord::Base.transaction do
      remove_column :currencies, :blockchain_key, :string
      remove_column :currencies, :deposit_fee, :decimal
      remove_column :currencies, :min_deposit_amount, :decimal
      remove_column :currencies, :min_collection_amount, :decimal
      remove_column :currencies, :withdraw_fee, :decimal
      remove_column :currencies, :min_withdraw_amount, :decimal
      remove_column :currencies, :withdraw_limit_24h, :decimal
      remove_column :currencies, :withdraw_limit_72h, :decimal
      remove_column :currencies, :options, :json
      remove_column :currencies, :visible, :boolean
      remove_column :currencies, :base_factor, :bigint
      remove_column :currencies, :deposit_enabled, :boolean
      remove_column :currencies, :withdrawal_enabled, :boolean
    end
    add_column :currencies, :status, :string, limit: 32, null: false, default: 'enabled', after: :type

    # Add new field to blockchain table
    add_column :blockchains, :description, :text, after: :height
    add_column :blockchains, :warning, :text, after: :description
    add_column :blockchains, :protocol, :string, after: :warning
  end

  def down
    # Add currencies fields
    ActiveRecord::Base.transaction do
      add_column :currencies, :blockchain_key, :string
      add_column :currencies, :deposit_fee, :decimal, after: :type, null: false, default: 0, precision: 32, scale: 16
      add_column :currencies, :min_deposit_amount, :decimal, precision: 32, scale: 16, default: 0.0, null: false, after: :deposit_fee
      add_column :currencies, :min_collection_amount, :decimal, precision: 32, scale: 16, default: 0.0, null: false, after: :min_deposit_amount
      add_column :currencies, :withdraw_fee, :decimal, precision: 32, scale: 16, default: 0.0, null: false, after: :min_collection_amount
      add_column :currencies, :min_withdraw_amount, :decimal, precision: 32, scale: 16, default: 0.0, null: false, after: :withdraw_fee
      add_column :withdraw_limit_24h, precision: 32, scale: 16, default: 0, null: false, after: :min_withdraw_amount
      add_column :withdraw_limit_72h, precision: 32, scale: 16, default: 0, null: false, after: :withdraw_limit_24h
      add_column :currencies, :options, :json, after: :withdraw_limit_72h
      add_column :currencies, :visible, :boolean, default: true, null: false, index: true, after: :options
      add_column :base_factor, default: 1, null: false, after: :visible
      add_column :deposit_enabled, default: true, null: false, after: :base_factor
      add_column :withdrawal_enabled, default: true, null: false, after: :deposit_enabled
    end

    Currency.find_each(batch_size: 10) do |currency|
      blockchain_currency = currency.blockchain_currencies[0]

      currency.update(
        blockchain_key: blockchain_currency.blockchain_key,
        deposit_fee: blockchain_currency.deposit_fee,
        min_deposit_amount: blockchain_currency.min_deposit_amount,
        min_collection_amount: blockchain_currency.min_collection_amount,
        withdraw_fee: blockchain_currency.withdraw_fee,
        min_withdraw_amount: blockchain_currency.min_withdraw_amount,
        withdraw_limit_24h: blockchain_currency.withdraw_limit_24h,
        withdraw_limit_72h: blockchain_currency.withdraw_limit_72h,
        deposit_enabled: blockchain_currency.deposit_enabled,
        withdrawal_enabled: blockchain_currency.withdrawal_enabled,
        base_factor: blockchain_currency.base_factor,
        visible: blockchain_currency.status,
        options: blockchain_currency.options
      )
    end

    remove_column :currencies, :status, :string

    remove_column :deposits, :blockchain_key, :string
    remove_column :withdraws, :blockchain_key, :string
    remove_column :payment_addresses, :blockchain_key, :string

    # Remove fields from blockchain table
    remove_column :blockchains, :description, :text
    remove_column :blockchains, :warning, :text
    remove_column :blockchains, :protocol, :string

    drop_table(:blockchain_currencies, force: true)
  end
end
