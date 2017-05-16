require 'test_helper'

class ItransactTest < Test::Unit::TestCase
  def setup
    @gateway = ItransactGateway.new(
                 :api_key => 'key',
                 :api_secret => 'secret',
               )

    @credit_card = credit_card
    @amount = 1014 # = $10.14
    
    @options = { 
      :email => 'name@domain.com',
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
    }
  end
  
  def test_successful_card_purchase
    response = mock
    response.expects(:body).returns(successful_card_purchase_response)
    response.expects(:code).returns('200')

    @gateway.expects(:raw_ssl_request).returns(response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    assert_equal 'tr_508LEItovSXZBSG8rD_DfQ', response.authorization
    assert response.test?
  end

  def test_unsuccessful_card_request
    response = mock
    response.expects(:body).returns(failed_purchase_response)
    response.expects(:code).returns('500')

    @gateway.expects(:raw_ssl_request).returns(response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private
  
  def successful_card_purchase_response
    "{\"id\":\"tr_508LEItovSXZBSG8rD_DfQ\",\"amount\":1060,\"status\":\"postauthed\",\"settled\":true,\"instrument\":\"cc\",\"metadata\":[{\"key\":\"email\",\"value\":\"email\"}]}"
  end
  
  def failed_purchase_response
	"{\"error\":{\"type\":\"TYPE\",\"message\":\"Cannot do something\",\"transaction_id\":\"tr_fBtcXiEj42sN3ynfTC2j4w\"}}"
  end

end
