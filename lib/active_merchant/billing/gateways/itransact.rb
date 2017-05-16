require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Please note, the username and API Access Key are not what you use to log into the Merchant Control Panel.
    #
    # ==== How to get your API Access Keys
    #
    # 1. If you don't already have a Gateway Account, go to http://www.itransact.com/merchant/test.html to sign up.
    # 2. Go to http://support.paymentclearing.com and login or register, if necessary.
    # 3. Click on "Submit a Ticket."
    # 4. Select "Merchant Support" as the department and click "Next"
    # 5. Enter *both* your company name and GatewayID. Put "API Access Key" in the subject.
    #
    # ==== Initialization
    #
    # Once you have your API Key and API Secret Key, you're ready
    # to begin.  You initialize the Gateway like so:
    #
    #   gateway = ActiveMerchant::Billing::ItransactGateway.new(
    #     :api_key => "#{API_KEY}",
    #     :api_secret => "#{API_SECRET}"
    #   )
    #
    # ==== Important Notes
    # 1. Recurring is not implemented
    # 2. TransactionStatus is not implemented
    #
    class ItransactGateway < Gateway
      self.live_url = 'https://api.itransact.com'
      self.test_url = 'https://test.api.itransact.com'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.itransact.com/'

      # The name of the gateway
      self.display_name = 'iTransact'

      #
      # Creates a new instance of the iTransact Gateway.
      #
      # ==== Parameters
      # * <tt>options</tt> - A Hash of options
      #
      # ==== Options Hash
      # * <tt>:api_key</tt> - A String containing your iTransact assigned API Access Username
      # * <tt>:api_secret</tt> - A String containing your iTransact assigned API Access Key
      # * <tt>:test_mode</tt> - <tt>true</tt> or <tt>false</tt>. Run *all* transactions with the 'TestMode' element set to 'TRUE'.
      #
      def initialize(options = {})
        requires!(options, :api_key, :api_secret)
        super
      end

      # Performs an authorize transaction.  In iTransact's documentation
      # this is known as a "PreAuth" transaction.
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be captured. Should be an Integer amount in cents.
      # * <tt>creditcard</tt> - The CreditCard details for the transaction
      # * <tt>options</tt> - A Hash of options
      #
      # ==== Options Hash
      # The standard options apply here (:order_id, :ip, :customer, :invoice, :merchant, :description, :email, :currency, :address, :billing_address, :shipping_address), as well as:
      # * <tt>:test_mode</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'TestMode' element set to 'TRUE' or 'FALSE'.
      #
      # ==== Examples
      #  response = gateway.authorize(1000, creditcard,
      #    :customer_id => '1212', :address => {...}, :email => 'test@test.com',
      #    :test_mode => true
      #  )
      #
      def authorize(money, payment_source, options = {})
        metadata = {
          email: options[:email]
        }.to_json

        payload = {
          amount: money,
          card: {
            number: payment_source.number,
            cvv: payment_source.verification_value,
            exp_month: payment_source.month,
            exp_year: payment_source.year
          },
          capture: false,
          metadata: metadata
        }

        if a = options[:billing_address]
          payload.merge!({
            address: {
              line1: a[:address1],
              line2: a[:address2],
              city: a[:city],
              state: a[:state],
              postal_code: a[:zip],
            }
          })
        end

        result = parse(ssl_request(:post,
         self.live_url + '/transactions',
         payload.to_json,
         'Content-Type' => 'application/json', 'Authorization' => "#{signed_api_key}:#{sign_payload(payload)}"
        ))

        Response.new(true, nil, result, test: test?, authorization: result['id'])
      rescue ResponseError => e
        result = parse(e.response.body)
        Response.new(false, result['error']['message'], result, test: test?, authorization: result['error']['transaction_id'])
      end

      # Performs an authorize and capture in single transaction. In iTransact's
      # documentation this is known as an "Auth" or a "Sale" transaction
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be captured. Should be <tt>nil</tt> or an Integer amount in cents.
      # * <tt>creditcard</tt> - The CreditCard details for the transaction
      # * <tt>options</tt> - A Hash of options
      #
      # ==== Options Hash
      # The standard options apply here (:order_id, :ip, :customer, :invoice, :merchant, :description, :email, :currency, :address, :billing_address, :shipping_address), as well as:
      # * <tt>:test_mode</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'TestMode' element set to 'TRUE' or 'FALSE'.
      #
      # ==== Examples
      #  response = gateway.purchase(1000, creditcard,
      #    :order_id => '1212', :address => {...}, :email => 'test@test.com',
      #    :test_mode => true
      #  )
      #
      def purchase(money, payment_source, options = {})
        metadata = {
          email: options[:email]
        }.to_json

        payload = {
          amount: money,
          card: {
            number: payment_source.number,
            cvv: payment_source.verification_value,
            exp_month: payment_source.month,
            exp_year: payment_source.year
          },
          capture: true,
          metadata: metadata
        }

        if a = options[:billing_address]
          payload.merge!({
            address: {
              line1: a[:address1],
              line2: a[:address2],
              city: a[:city],
              state: a[:state],
              postal_code: a[:zip],
            }
          })
        end

        result = parse(ssl_request(:post,
         self.live_url + '/transactions',
         payload.to_json,
         'Content-Type' => 'application/json', 'Authorization' => "#{signed_api_key}:#{sign_payload(payload)}"
        ))

        Response.new(true, nil, result, test: test?, authorization: result['id'])
      rescue ResponseError => e
        result = parse(e.response.body)
        Response.new(false, result['error']['message'], result, test: test?, authorization: result['error']['transaction_id'])
      end

      # Captures the funds from an authorize transaction.  In iTransact's
      # documentation this is known as a "PostAuth" transaction.
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be captured. Should be an Integer amount in cents
      # * <tt>authorization</tt> - The authorization returned from the previous capture or purchase request
      # * <tt>options</tt> - A Hash of options, all are optional.
      #
      # ==== Options Hash
      # The standard options apply here (:order_id, :ip, :customer, :invoice, :merchant, :description, :email, :currency, :address, :billing_address, :shipping_address), as well as:
      # * <tt>:test_mode</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'TestMode' element set to 'TRUE' or 'FALSE'.
      #
      # ==== Examples
      #  response = gateway.capture(1000, creditcard,
      #    :test_mode => true
      #  )
      #
      def capture(money, authorization, options = {})
        payload = { id: authorization, amount: money }

        result = parse(ssl_request(:patch,
         self.live_url + '/transactions/' + authorization + '/capture',
         payload.to_json,
         'Content-Type' => 'application/json', 'Authorization' => "#{signed_api_key}:#{sign_payload(payload)}"
        ))

        Response.new(true, nil, result, test: test?, authorization: result['id'])
      rescue ResponseError => e
        result = parse(e.response.body)
        Response.new(false, result['error']['message'], result, test: test?, authorization: result['error']['transaction_id'])
      end

      # This will reverse a previously run transaction which *has* *not* settled.
      #
      # ==== Parameters
      # * <tt>authorization</tt> - The authorization returned from the previous capture or purchase request
      # * <tt>options</tt> - A Hash of options, all are optional
      #
      # ==== Options Hash
      # The standard options (:order_id, :ip, :customer, :invoice, :merchant, :description, :email, :currency, :address, :billing_address, :shipping_address) are ignored.
      # * <tt>:test_mode</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'TestMode' element set to 'TRUE' or 'FALSE'.
      #
      # ==== Examples
      #  response = gateway.void('9999999999',
      #    :test_mode => true
      #  )
      #
      def void(authorization, options = {})
        payload = { id: authorization }

        result = parse(ssl_request(:patch,
         self.live_url + '/transactions/' + authorization + '/void',
         payload.to_json,
         'Content-Type' => 'application/json', 'Authorization' => "#{signed_api_key}:#{sign_payload(payload)}"
        ))

        Response.new(true, nil, result, test: test?, authorization: result['id'])
      rescue ResponseError => e
        result = parse(e.response.body)
        Response.new(false, result['error']['message'], result, test: test?, authorization: result['error']['transaction_id'])
      end

      # This will reverse a previously run transaction which *has* settled.
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be credited. Should be an Integer amount in cents
      # * <tt>authorization</tt> - The authorization returned from the previous capture or purchase request
      # * <tt>options</tt> - A Hash of options, all are optional
      #
      # ==== Options Hash
      # The standard options (:order_id, :ip, :customer, :invoice, :merchant, :description, :email, :currency, :address, :billing_address, :shipping_address) are ignored.
      # * <tt>:test_mode</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'TestMode' element set to 'TRUE' or 'FALSE'.
      #
      # ==== Examples
      #  response = gateway.refund(555, '9999999999',
      #    :test_mode => true
      #  )
      #
      def refund(money, authorization, options = {})
        payload = { id: authorization, amount: money }

        result = parse(ssl_request(:patch,
         self.live_url + '/transactions/' + authorization + '/credit',
         payload.to_json,
         'Content-Type' => 'application/json', 'Authorization' => "#{signed_api_key}:#{sign_payload(payload)}"
        ))

        Response.new(true, nil, result, test: test?, authorization: result['id'])
      rescue ResponseError => e
        result = parse(e.response.body)
        Response.new(false, result['error']['message'], result, test: test?, authorization: result['error']['transaction_id'])
      end

      private

      def parse(raw_json)
        JSON.parse(raw_json)
      end

      def test_mode?(response)
        # The '1' is a legacy thing; most of the time it should be 'TRUE'...
        response[:test_mode] == 'TRUE' || response[:test_mode] == '1'
      end

      def signed_api_key
        Base64.strict_encode64(@options[:api_key])
      end

      def sign_payload(payload)
        key = @options[:api_secret].to_s
        digest = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new(key), key, payload.to_json)
        signature = Base64.strict_encode64(digest)
        signature
      end
    end
  end
end

