# frozen_string_literal: true

module API
  module V2
    module Admin
      class BlockchainCurrencies < Grape::API
        helpers ::API::V2::Admin::Helpers
        helpers do
          # Collection of shared params, used to
          # generate required/optional Grape params.
          OPTIONAL_CURRENCY_PARAMS ||= {
            deposit_fee: {
              type: { value: BigDecimal, message: 'admin.blockchain_currency.non_decimal_deposit_fee' },
              values: { value: -> (p){ p >= 0 }, message: 'admin.blockchain_currency.invalid_deposit_fee' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:deposit_fee][:desc] }
            },
            min_deposit_amount: {
              type: { value: BigDecimal, message: 'admin.blockchain_currency.min_deposit_amount' },
              values: { value: -> (p){ p >= 0 }, message: 'admin.blockchain_currency.min_deposit_amount' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:min_deposit_amount][:desc] }
            },
            min_collection_amount: {
              type: { value: BigDecimal, message: 'admin.blockchain_currency.non_decimal_min_collection_amount' },
              values: { value: -> (p){ p >= 0 }, message: 'admin.blockchain_currency.invalid_min_collection_amount' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:min_collection_amount][:desc] }
            },
            withdraw_fee: {
              type: { value: BigDecimal, message: 'admin.blockchain_currency.non_decimal_withdraw_fee' },
              values: { value: -> (p){ p >= 0  }, message: 'admin.blockchain_currency.ivalid_withdraw_fee' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:withdraw_fee][:desc] }
            },
            min_withdraw_amount: {
              type: { value: BigDecimal, message: 'admin.blockchain_currency.non_decimal_min_withdraw_amount' },
              values: { value: -> (p){ p >= 0 }, message: 'admin.blockchain_currency.invalid_min_withdraw_amount' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:min_withdraw_amount][:desc] }
            },
            withdraw_limit_24h: {
              type: { value: BigDecimal, message: 'admin.blockchain_currency.non_decimal_withdraw_limit_24h' },
              values: { value: -> (p){ p >= 0 }, message: 'admin.blockchain_currency.invalid_withdraw_limit_24h' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:withdraw_limit_24h][:desc] }
            },
            withdraw_limit_72h: {
              type: { value: BigDecimal, message: 'admin.blockchain_currency.non_decimal_withdraw_limit_72h' },
              values: { value: -> (p){ p >= 0 }, message: 'admin.blockchain_currency.invalid_withdraw_limit_72h' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:withdraw_limit_72h][:desc] }
            },
            options: {
              type: { value: JSON, message: 'admin.blockchain_currency.non_json_options' },
              default: {},
              desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:options][:desc] }
            },
            status: {
              values: { value: -> { ::BlockchainCurrency::STATES }, message: 'admin.currency.invalid_status'},
              desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:status][:desc] }
            },
            deposit_enabled: {
              type: { value: Boolean, message: 'admin.blockchain_currency.non_boolean_deposit_enabled' },
              default: true,
              desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:deposit_enabled][:desc] }
            },
            withdrawal_enabled: {
              type: { value: Boolean, message: 'admin.blockchain_currency.non_boolean_withdrawal_enabled' },
              default: true,
              desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:withdrawal_enabled][:desc] }
            },
          }

          params :create_blockchain_currency_params do
            OPTIONAL_CURRENCY_PARAMS.each do |key, params|
              optional key, params
            end
          end

          params :update_blockchain_currency_params do
            OPTIONAL_CURRENCY_PARAMS.each do |key, params|
              optional key, params.except(:default)
            end
          end
        end

        namespace :blockchain_currencies do
          desc 'Get all blockchain currencies, result is paginated.',
            is_array: true,
            success: API::V2::Admin::Entities::BlockchainCurrency
          params do
            use :pagination
            use :ordering
            optional :deposit_enabled,
                     type: { value: Boolean, message: 'admin.blockchain_currency.non_boolean_deposit_enabled' },
                     desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:deposit_enabled][:desc] }
            optional :withdrawal_enabled,
                     type: { value: Boolean, message: 'admin.blockchain_currency.non_boolean_withdrawal_enabled' },
                     desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:withdrawal_enabled][:desc] }
          end
          get do
            admin_authorize! :read, ::BlockchainCurrency

            ransack_params = Helpers::RansackBuilder.new(params)
                               .eq(:status, :withdrawal_enabled, :deposit_enabled)
                               .build

            search = ::BlockchainCurrency.ransack(ransack_params)
            search.sorts = "#{params[:order_by]} #{params[:ordering]}"
            present paginate(search.result), with: API::V2::Admin::Entities::BlockchainCurrency
          end

          desc 'Create new blockchain currency.' do
            success API::V2::Admin::Entities::BlockchainCurrency
          end
          params do
            use :create_blockchain_currency_params
            requires :currency_id,
                     allow_blank: false,
                     values: { value: -> { Currency.codes(bothcase: true) }, message: 'admin.blockchain_currency.currency_doesnt_exist'},
                     desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:currency_id][:desc] }
            requires :blockchain_key,
                     allow_blank: false,
                     values: { value: -> { ::Blockchain.pluck(:key) }, message: 'admin.blockchain_currency.blockchain_key_doesnt_exist' },
                     desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:base_factor][:desc] }
            optional :base_factor,
                     type: { value: Integer, message: 'admin.blockchain_currency.non_integer_base_factor' },
                     desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:base_factor][:desc] }
            optional :subunits,
                     type: { value: Integer, message: 'admin.blockchain_currency.non_integer_subunits' },
                     values: { value: (0..18), message: 'admin.blockchain_currency.invalid_subunits' },
                     desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:subunits][:desc] }
            mutually_exclusive :base_factor, :subunits, message: 'admin.blockchain_currency.one_of_base_factor_subunits_fields'
          end
          post '/new' do
            admin_authorize! :create, ::BlockchainCurrency
            blockchain_currency = ::BlockchainCurrency.new(declared(params, include_missing: false))

            if blockchain_currency.save
              present blockchain_currency, with: API::V2::Admin::Entities::BlockchainCurrency
              status 201
            else
              body errors: blockchain_currency.errors.full_messages
              status 422
            end
          end

          desc 'Get a blockchain currency.' do
            success API::V2::Admin::Entities::BlockchainCurrency
          end
          params do
            requires :id,
                     type: Integer,
                     desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:id][:desc] }
          end
          get '/:id' do
            admin_authorize! :read, ::BlockchainCurrency

            present ::BlockchainCurrency.find(params[:id]), with: API::V2::Admin::Entities::BlockchainCurrency
          end
        end

        desc 'Update blockchain currency.' do
          success API::V2::Admin::Entities::BlockchainCurrency
        end
        params do
          use :update_blockchain_currency_params
          requires :id,
                   type: Integer,
                   desc: -> { API::V2::Admin::Entities::BlockchainCurrency.documentation[:id][:desc] }
        end
        post '/update' do
          admin_authorize! :update, ::BlockchainCurrency, params.except(:id)

          blockchain_currency = ::BlockchainCurrency.find(params[:id])
          if blockchain_currency.update(declared(params, include_missing: false))
            present blockchain_currency, with: API::V2::Admin::Entities::BlockchainCurrency
          else
            body errors: blockchain_currency.errors.full_messages
            status 422
          end
        end
      end
    end
  end
end
