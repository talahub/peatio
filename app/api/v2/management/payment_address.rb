# frozen_string_literal: true

module API
  module V2
    module Management
      class PaymentAddress < Grape::API
        desc 'Create payment address' do
          @settings[:scope] = :write_payment_addresses
          success API::V2::Management::Entities::PaymentAddress
        end

        params do
          requires :uid,
                    type: String,
                    values: { value: ->(v) { Member.exists?(uid: v) }, message: 'management.payment_address.uid_doesnt_exist' },
                    desc: API::V2::Management::Entities::PaymentAddress.documentation[:uid][:desc]
          requires :currency,
                    type: String,
                    values: { value: -> { Currency.codes(bothcase: true) }, message: 'management.payment_address.currency_doesnt_exist' },
                    desc: -> { API::V2::Management::Entities::Currency.documentation[:code][:desc] }
          requires :blockchain_key,
                   values: { value: -> { ::Blockchain.pluck(:key) }, message: 'management.payment_address.blockchain_key_doesnt_exist' },
                   allow_blank: false,
                   desc: 'Blockchain key of the requested deposit address'
          optional :remote,
                    type: { value: Boolean, message: 'management.payment_address.non_boolean_remote' },
                    desc: API::V2::Management::Entities::PaymentAddress.documentation[:remote][:desc]
        end

        post '/deposit_address/new' do
          member = Member.find_by(uid: params[:uid]) if params[:uid].present?

          currency = Currency.find(params[:currency])
          blockchain_currency = BlockchainCurrency.find_by!(currency_id: params[:currency_id],
                                                            blockchain_key: params[:blockchain_key])
          unless blockchain_currency.deposit_enabled?
            error!({ errors: ['management.currency.deposit_disabled'] }, 422)
          end

          wallet = Wallet.deposit_wallet(currency.id, blockchain_currency.blockchain_key)
          unless wallet.present?
            error!({ errors: ['management.wallet.not_found'] }, 422)
          end

          unless params[:remote].nil?
            pa = member.payment_address!(wallet.id, params[:remote])
          else
            pa = member.payment_address!(wallet.id)
          end

          wallet_service = WalletService.new(wallet)

          begin
            pa.with_lock do
              next if pa.address.present?

              # Supply address ID in case of BitGo address generation if it exists.
              result = wallet_service.create_address!(member.uid, pa.details.merge(updated_at: pa.updated_at))
              if result.present?
                pa.update!(address: result[:address],
                          secret:  result[:secret],
                          details: result.fetch(:details, {}).merge(pa.details))
              end
            end

            present pa, with: API::V2::Management::Entities::PaymentAddress
            status 200
          rescue StandardError => e
            Rails.logger.error { "Error: #{e} while generating payment address for #{params[:currency]} for user: #{params[:uid]}" }
            error!({ errors: ['management.payment_address.failed_to_generate'] }, 422)
          end
        end
      end
    end
  end
end
