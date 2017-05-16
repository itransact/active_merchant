require 'test_helper'

class RemoteItransactTest < Test::Unit::TestCase
  
  def setup
    @gateway = ItransactGateway.new(fixtures(:itransact))
    
    @amount = 1060
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_nil response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert response = @gateway.authorize(amount, @credit_card, @options)
    assert_success response
    assert_nil response.message
    assert response.authorization
    assert capture = @gateway.capture(amount, response.authorization)
    assert_success capture
  end

  def test_authorize_and_void
    amount = @amount
    response = @gateway.authorize(amount, @credit_card, @options)
    puts response
    assert response
    assert_success response
    assert_nil response.message
    assert response.authorization
    assert capture = @gateway.void(response.authorization)
    assert_success capture
  end

  def test_invalid_login
    gateway = ItransactGateway.new(api_key: 'x', api_secret: 'x')

    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Unauthorized', response.message
  end
end
