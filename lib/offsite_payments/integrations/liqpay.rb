module OffsitePayments #:nodoc:
  module Integrations #:nodoc:
    # Documentation: https://www.liqpay.com/doc
    module Liqpay
      mattr_accessor :service_url
      self.service_url = 'https://www.liqpay.com/api/checkout'

      mattr_accessor :signature_parameter_name
      self.signature_parameter_name = 'signature'

      def self.helper(order, account, options = {})
        Helper.new(order, account, options)
      end

      def self.notification(query_string, options = {})
        Notification.new(query_string, options)
      end

      def self.return(query_string)
        Return.new(query_string)
      end

      class Helper < OffsitePayments::Helper

        LIQPAY_FIELDS = [:version, :public_key, :amount, :currency, :description, :order_id,
                         :type, :subscribe, :subscribe_date_start, :subscribe_periodicity,
                         :server_url, :result_url, :pay_way, :language, :sandbox]

        def initialize(order, account, options = {})
          @public_key = options.delete(:public_key)
          @private_key = options.delete(:private_key)
          super

          add_field 'version', '3'
        end

        def form_fields
          json = {}
          LIQPAY_FIELDS.each do |field|
            value = field == :public_key ? @public_key : @fields[field.to_s]
            json[field] = value if !value.nil?
          end
          data = Base64.encode64(JSON.generate(json))
          {
            'data' => data,
            'signature' => Base64.encode64(Digest::SHA1.digest("#{@private_key}#{data}#{@private_key}")).strip
          }
        end

        mapping :account, 'merchant_id'
        mapping :amount, 'amount'
        mapping :currency, 'currency'
        mapping :order, 'order_id'
        mapping :description, 'description'
        mapping :phone, 'default_phone'

        mapping :notify_url, 'server_url'
        mapping :return_url, 'result_url'
      end

      class Notification < OffsitePayments::Notification
        def self.recognizes?(params)
          params.has_key?('amount') && params.has_key?('order_id')
        end

        def initialize(post, options = {})
          raise ArgumentError if post.blank?
          super
          @params.merge!(JSON.parse(Base64.decode64(json)))
        end

        def json
          @params['data']
        end

        def complete?
          status == 'success' || status == 'sandbox'
        end

        def amount
          BigDecimal.new(gross)
        end

        def item_id
          params['order_id']
        end
        alias_method :order_id, :item_id

        def transaction_id
          params['transaction_id']
        end

        def action_name
          params['action_name'] # either 'result_url' or 'server_url'
        end

        def version
          params['version']
        end

        def sender_phone
          params['sender_phone']
        end

        def security_key
          params[OffsitePayments::Integrations::Liqpay.signature_parameter_name]
        end

        def gross
          params['amount']
        end

        def currency
          params['currency']
        end

        # Available values:
        #
        # * success
        # * failure
        # * wait_secure
        # * wait_accept
        # * wait_lc
        # * processing
        # * sandbox
        # * subscribed
        # * unsubscribed
        # * reversed
        def status
          params['status'] # 'success', 'failure' or 'wait_secure'
        end

        def description
          params['description']
        end

        # Available values:
        #
        # * buy
        # * donate
        def type
          params['type']
        end

        def generate_signature_string
          "#{@options[:public_key]}#{Base64.decode64(json)}#{@options[:public_key]}"
        end

        def generate_signature
          Base64.encode64(Digest::SHA1.digest(generate_signature_string)).strip
        end

        def acknowledge(authcode = nil)
          security_key == generate_signature
        end
      end

      class Return < OffsitePayments::Return
        def self.recognizes?(params)
          params.has_key?('amount') && params.has_key?('order_id')
        end

        def initialize(post)
          super
          json = Base64.decode64(@params['data'])
          @params.merge!(JSON.parse(json))
        end

        def complete?
          status == 'success' || status == 'sandbox'
        end

        def amount
          BigDecimal.new(gross)
        end

        def item_id
          params['order_id']
        end
        alias_method :order_id, :item_id

        def transaction_id
          params['transaction_id']
        end

        def action_name
          params['action_name'] # either 'result_url' or 'server_url'
        end

        def version
          params['version']
        end

        def sender_phone
          params['sender_phone']
        end

        def security_key
          params[OffsitePayments::Integrations::Liqpay.signature_parameter_name]
        end

        def gross
          params['amount']
        end

        def currency
          params['currency']
        end

        # Available values:
        #
        # * success
        # * failure
        # * wait_secure
        # * wait_accept
        # * wait_lc
        # * processing
        # * sandbox
        # * subscribed
        # * unsubscribed
        # * reversed
        def status
          params['status'] # 'success', 'failure' or 'wait_secure'
        end

        def description
          params['description']
        end

        # Available values:
        #
        # * buy
        # * donate
        def type
          params['type']
        end

        def generate_signature_string
          fields = [:version, :public_key, :amount, :currency, :description, :order_id,
                    :type, :sender_phone]
          json = {}
          fields.each do |field|
            value = field == :public_key ?  @options[:public_key] : send(field)
            json[field] = value if value
          end
          [@options[:private_key], Base64.encode64(JSON.generate(json)), @options[:private_key]].join('')
        end

        def generate_signature
          Base64.encode64(Digest::SHA1.digest(generate_signature_string)).gsub(/\n/, '')
        end

        def acknowledge(authcode = nil)
          security_key == generate_signature
        end
      end
    end
  end
end
