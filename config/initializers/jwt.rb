# encoding: UTF-8
# frozen_string_literal: true

Rails.configuration.x.jwt_public_key =
  if ENV['JWT_PUBLIC_KEY'].present?
    key = OpenSSL::PKey.read(Base64.urlsafe_decode64(ENV['JWT_PUBLIC_KEY']))
    raise ArgumentError, 'JWT_PUBLIC_KEY was set to private key, however it should be public.' if key.private?
    key
  end

Rails.configuration.x.jwt_options = {
  algorithm: ENV.fetch('JWT_ALGORITHM', 'RS256'),
  verify_expiration: true,
  # verify_not_before: true,
  # iss: ENV['JWT_ISSUER'],
  # verify_iss: ENV['JWT_ISSUER'].present?,
  # verify_iat: true,
  # verify_jti: true,
  # aud: ENV['JWT_AUDIENCE'].to_s.split(',').reject(&:blank?),
  # verify_aud: ENV['JWT_AUDIENCE'].present?,
  # sub: 'session',
  # verify_sub: true,
}

require 'yaml'
require 'openssl'

(YAML.load_file('config/management_api_v1.yml') || {}).deep_symbolize_keys.tap do |x|
  x.fetch(:keychain).each do |id, key|
    key = OpenSSL::PKey.read(Base64.urlsafe_decode64(key.fetch(:value)))
    if key.private?
      raise ArgumentError, 'keychain.' + id.to_s + ' was set to private key, ' \
                           'however it should be public (in config/management_api_v1.yml).'
    end
    x[:keychain][id][:value] = key
  end

  x.fetch(:scopes).values.each do |scope|
    %i[permitted_signers mandatory_signers].each do |list|
      scope[list] = scope.fetch(list, []).map(&:to_sym)
      scope[list] = scope.fetch(list, []).map(&:to_sym)
      if list == :mandatory_signers && scope[list].empty?
        raise ArgumentError, 'scopes.' + scope.to_s + '.' + list.to_s + ' is empty, ' \
                             'however it should contain at least one value (in config/management_api_v1.yml).'
      end
    end
  end

  Rails.configuration.x.security_configuration = x
end
