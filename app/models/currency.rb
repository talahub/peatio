# encoding: UTF-8
# frozen_string_literal: true

class Currency < ApplicationRecord

  # == Constants ============================================================

  TOP_POSITION = 1
  STATES = %w[enabled disabled hidden].freeze
  # enabled - user can deposit and withdraw.
  # disabled - none can view, deposit and withdraw.
  # hidden - user can't view, but can deposit and withdraw.

  # == Attributes ===========================================================

  attr_readonly :id,
                :type

  # Code is aliased to id because it's more user-friendly primary key.
  # It's preferred to use code where this attributes are equal.
  alias_attribute :code, :id

  # == Extensions ===========================================================

  include Helpers::ReorderPosition

  # == Relationships ========================================================

  has_and_belongs_to_many :wallets

  has_one :parent, class_name: 'Currency', foreign_key: :id, primary_key: :parent_id

  has_many :blockchain_currencies

  # == Validations ==========================================================

  validate on: :create do
    if ENV['MAX_CURRENCIES'].present? && Currency.count >= ENV['MAX_CURRENCIES'].to_i
      errors.add(:max, 'Currency limit has been reached')
    end
  end

  validates :code, presence: true, uniqueness: { case_sensitive: false }

  validates :position,
            presence: true,
            numericality: { greater_than_or_equal_to: TOP_POSITION, only_integer: true }

  validates :parent_id, allow_blank: true,
            inclusion: { in: ->(_) { Currency.coins_without_tokens.pluck(:id).map(&:to_s) } },
            if: :coin?

  validates :type, inclusion: { in: ->(_) { Currency.types.map(&:to_s) } }

  validates :precision, numericality: { greater_than_or_equal_to: 0 }

  validates :status, inclusion: { in: STATES }

  # == Scopes ===============================================================

  scope :visible, -> { where(status: :enabled) }
  scope :active, -> { where(status: %i[enabled hidden]) }
  scope :ordered, -> { order(position: :asc) }
  scope :coins, -> { where(type: :coin) }
  scope :fiats, -> { where(type: :fiat) }
  # This scope select all coins without parent_id, which means that they are not tokens
  scope :coins_without_tokens, -> { coins.where(parent_id: nil) }

  # == Callbacks ============================================================

  after_create do
    link_wallets
    insert_position(self)
  end

  before_validation { self.code = code.downcase }
  before_validation(on: :create) { self.position = Currency.count + 1 unless position.present? }

  before_update { update_position(self) if position_changed? }

  after_commit :wipe_cache

  # == Class Methods ========================================================

  # NOTE: type column reserved for STI
  self.inheritance_column = nil

  class << self
    def codes(options = {})
      pluck(:id).yield_self do |downcase_codes|
        case
        when options.fetch(:bothcase, false)
          downcase_codes + downcase_codes.map(&:upcase)
        when options.fetch(:upcase, false)
          downcase_codes.map(&:upcase)
        else
          downcase_codes
        end
      end
    end

    def types
      %i[fiat coin].freeze
    end
  end

  # == Instance Methods =====================================================

  types.each { |t| define_method("#{t}?") { type == t.to_s } }

  def wipe_cache
    Rails.cache.delete_matched("currencies*")
  end

  def link_wallets
    if parent_id.present?
      # Iterate through active deposit/withdraw wallets
      Wallet.active.where.not(kind: :fee).with_currency(parent_id).each do |wallet|
        # Link parent currency with wallet
        CurrencyWallet.create(currency_id: id, wallet_id: wallet.id)
      end
    end
  end

  # Allows to dynamically check value of id/code:
  #
  #   id.btc? # true if code equals to "btc".
  #   code.eth? # true if code equals to "eth".
  def id
    super&.inquiry
  end

  # This method defines that token currency need to have parent_id and coin type
  # We use parent_id for token type to inherit some useful info such as blockchain_key from parent currency
  # For coin currency enough to have only coin type
  def token?
    parent_id.present? && coin?
  end

  def get_price
    if price.blank? || price.zero?
      raise "Price for currency #{id} is unknown"
    else
      price
    end
  end

  def dependent_markets
    Market.where('base_unit = ? OR quote_unit = ?', id, id)
  end
end

# == Schema Information
# Schema version: 20201207134745
#
# Table name: currencies
#
#  id                    :string(10)       not null, primary key
#  name                  :string(255)
#  description           :text(65535)
#  homepage              :string(255)
#  blockchain_key        :string(32)
#  parent_id             :string(255)
#  type                  :string(30)       default("coin"), not null
#  deposit_fee           :decimal(32, 16)  default(0.0), not null
#  min_deposit_amount    :decimal(32, 16)  default(0.0), not null
#  min_collection_amount :decimal(32, 16)  default(0.0), not null
#  withdraw_fee          :decimal(32, 16)  default(0.0), not null
#  min_withdraw_amount   :decimal(32, 16)  default(0.0), not null
#  withdraw_limit_24h    :decimal(32, 16)  default(0.0), not null
#  withdraw_limit_72h    :decimal(32, 16)  default(0.0), not null
#  position              :integer          not null
#  options               :json
#  visible               :boolean          default(TRUE), not null
#  deposit_enabled       :boolean          default(TRUE), not null
#  withdrawal_enabled    :boolean          default(TRUE), not null
#  base_factor           :bigint           default(1), not null
#  precision             :integer          default(8), not null
#  icon_url              :string(255)
#  price                 :decimal(32, 16)  default(1.0), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_currencies_on_parent_id  (parent_id)
#  index_currencies_on_position   (position)
#  index_currencies_on_visible    (visible)
#
