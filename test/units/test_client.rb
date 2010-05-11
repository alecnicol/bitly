require 'test_helper'

class TestClient < Test::Unit::TestCase
  context "creating a new client" do
    should "initialize with login and api key" do
      assert_nothing_raised do
        client = Bitly::Client.new(login, api_key)
      end
    end
  end
  
  context "with a valid client" do
    setup do
      @bitly = Bitly::Client.new(login, api_key)
    end
    
    context "validating another account credentials" do
      context "with valid credentials" do
        setup do
          stub_get(%r|http://api\.bit\.ly/v3/validate?.*x_login=correct.*|, "valid_user.json")
        end
        should "return true" do
          assert @bitly.validate('correct','well_done')
        end
        should "return true for valid? as well" do
          assert @bitly.valid?('correct','well_done')
        end
      end
      context "with invalid credentials" do
        setup do
          stub_get(%r|http://api\.bit\.ly/v3/validate?.*x_login=wrong.*|,"invalid_user.json")
        end
        should "return false" do
          assert !@bitly.validate('wrong','so_very_wrong')
        end
        should "return false for valid? too" do
          assert !@bitly.valid?('wrong','so_very_wrong')
        end
      end
    end
    
    context "checking a bitly pro domain" do
      context "with a bitly pro domain" do
        setup do
          stub_get(%r|http://api\.bit\.ly/v3/bitly_pro_domain?.*domain=nyti\.ms.*|, 'bitly_pro_domain.json')
        end
        should "return true" do
          assert @bitly.bitly_pro_domain('nyti.ms')
        end
      end
      context "with a non bitly pro domain" do
        setup do
          stub_get(%r|http://api\.bit\.ly/v3/bitly_pro_domain?.*domain=philnash\.co\.uk.*|, 'not_bitly_pro_domain.json')
        end
        should "return true" do
          assert !@bitly.bitly_pro_domain('philnash.co.uk')
        end
      end
      context "with an invalid domain" do
        setup do
          stub_get(%r|http://api\.bit\.ly/v3/bitly_pro_domain?.*domain=philnash.*|, 'invalid_bitly_pro_domain.json')
        end
        should "raise an error" do
          assert_raise BitlyError do
            @bitly.bitly_pro_domain('philnash')
          end
        end
      end
    end
    
    context "shortening a url" do
      context "with just the url" do
        setup do
          @long_url = "http://betaworks.com/"
          stub_get(%r|http://api\.bit\.ly/v3/shorten\?.*longUrl=http%3A%2F%2Fbetaworks.com.*|, ['betaworks.json', 'betaworks2.json'])
          @url = @bitly.shorten(@long_url)
        end
        should "return a url object" do
          assert_instance_of Bitly::Url, @url
        end
        should "shorten the url" do
          assert_equal 'http://bit.ly/9uX1TE', @url.short_url
        end
        should "return the original long url" do
          assert_equal @long_url, @url.long_url
        end
        should "return a hash" do
          assert_equal '9uX1TE', @url.user_hash
        end
        should "return a global hash" do
          assert_equal '18H1ET', @url.global_hash
        end
        should "be a new hash the first time" do
          assert @url.new_hash?
        end
        should "not be a new hash the second time" do
          new_url = @bitly.shorten(@long_url)
          assert !new_url.new_hash?
          assert_not_same @url, new_url
        end
      end
      
      context "with extra options" do
        context "with the j.mp domain" do
          setup do
            stub_get( 'http://api.bit.ly/v3/shorten?longUrl=http%3A%2F%2Fbetaworks.com%2F&apiKey=test_key&login=test_account&domain=j.mp', 'betaworks_jmp.json'
            )
            @url = @bitly.shorten('http://betaworks.com/', :domain => "j.mp")
          end
          should "return a j.mp short url" do
            assert_equal "http://j.mp/9uX1TE", @url.short_url
          end
        end
        context "with another domain" do
          setup do
            stub_get( 'http://api.bit.ly/v3/shorten?longUrl=http%3A%2F%2Fbetaworks.com%2F&apiKey=test_key&login=test_account&domain=nyti.ms', 'invalid_domain.json'
            )
          end
          should "raise an error" do
            assert_raise BitlyError do
              url = @bitly.shorten('http://betaworks.com/', :domain => "nyti.ms")
            end
          end
        end
        context "with another user details" do
          context "with correct details" do
            setup do
              @long_url = "http://betaworks.com/"
              stub_get(%r|http://api\.bit\.ly/v3/shorten?.*longUrl=http%3A%2F%2Fbetaworks.com.*|, 'betaworks.json')
              stub_get( 'http://api.bit.ly/v3/shorten?longUrl=http%3A%2F%2Fbetaworks.com%2F&apiKey=test_key&login=test_account&x_login=other_account&x_apiKey=other_apiKey', 'betaworks_other_user.json'
              )
              @normal_url = @bitly.shorten(@long_url)
              @other_user_url = @bitly.shorten(@long_url, :x_login => 'other_account', :x_apiKey => 'other_apiKey')
            end
            should "return a different hash" do
              assert_not_equal @normal_url.user_hash, @other_user_url.user_hash
            end
            should "return a new hash" do
              assert @other_user_url.new_hash?
            end
          end
          context "without an api key" do
            setup do
              stub_get( 'http://api.bit.ly/v3/shorten?longUrl=http%3A%2F%2Fbetaworks.com%2F&apiKey=test_key&login=test_account&x_login=other_account', 'invalid_x_api_key.json'
              )
            end
            should "raise an error" do
              assert_raise BitlyError do
                @bitly.shorten('http://betaworks.com/', :x_login => 'other_account')
              end
            end
          end
        end
      end
    end
    
    context "expanding a url" do
      context "a single url" do
        context "with a hash" do
          setup do
            @hash = '9uX1TE'
            stub_get(%r|http://api\.bit\.ly/v3/expand\?.*hash=9uX1TE.*|, '9uX1TE.json')
            @url = @bitly.expand(@hash)
          end
          should 'return a url object' do
            assert_instance_of Bitly::Url, @url
          end
          should 'return the original hash' do
            assert_equal @hash, @url.user_hash
          end
          should "return a global hash" do
            assert_equal '18H1ET', @url.global_hash
          end
          should 'return a long url' do
            assert_equal 'http://betaworks.com/', @url.long_url
          end
          should 'return a short url' do
            assert_equal "http://bit.ly/#{@hash}", @url.short_url
          end
        end
        context "with the short url" do
          setup do
            @short_url = 'http://bit.ly/9uX1TE'
            stub_get(%r|http://api\.bit\.ly/v3/expand\?.*shortUrl=http%3A%2F%2Fbit\.ly%2F9uX1TE.*|, 'bitly9uX1TE.json')
            @url = @bitly.expand(@short_url)
          end
          should 'return a url object' do
            assert_instance_of Bitly::Url, @url
          end
          should 'return the original hash' do
            assert_equal @hash, @url.user_hash
          end
          should "return a global hash" do
            assert_equal '18H1ET', @url.global_hash
          end
          should 'return a long url' do
            assert_equal 'http://betaworks.com/', @url.long_url
          end
        end
        context "that doesn't exist" do
          setup do
            @shortUrl = 'http://bit.ly/9uX1TEsd'
            stub_get(%r|http://api\.bit\.ly/v3/expand\?.*shortUrl=http%3A%2F%2Fbit\.ly%2F9uX1TEsd.*|, 'missing_hash.json')
            @url = @bitly.expand(@shortUrl)
          end
          should 'return a missing url' do
            assert_instance_of Bitly::MissingUrl, @url
          end
          should 'return an error' do
            assert_equal 'NOT_FOUND', @url.error
          end
          should 'return the original url' do
            assert_equal @shortUrl, @url.short_url
          end
        end
      end
      context "multiple urls" do
        setup do
          @hash = '9uX1TE'
          @short_url = 'http://bit.ly/cEFx9W'
          stub_get("http://api.bit.ly/v3/expand?hash=9uX1TE&shortUrl=http%3A%2F%2Fbit.ly%2FcEFx9W&login=test_account&apiKey=test_key", 'multiple_urls.json')
          @urls = @bitly.expand([@hash, @short_url])
        end
        should "return an array of results" do
          assert_instance_of Array, @urls
        end
        should "return an array of bitly urls" do
          @urls.each { |url| assert_instance_of Bitly::Url, url }
        end
        should "return the original url" do
          assert_equal 'http://betaworks.com/', @urls[0].long_url
          assert_equal 'http://philnash.co.uk', @urls[1].long_url
        end
      end
    end

    context "clicks for urls" do
      context "with multiple urls" do
        setup do
          @hash = '9uX1TE'
          @short_url = 'http://bit.ly/cEFx9W'
          stub_get("http://api.bit.ly/v3/clicks?hash=9uX1TE&shortUrl=http%3A%2F%2Fbit.ly%2FcEFx9W&login=test_account&apiKey=test_key", 'multiple_url_click.json')
          @urls = @bitly.clicks([@hash, @short_url])
        end
        
        should "return an array of results" do
          assert_instance_of Array, @urls
        end
        should "return an array of bitly urls" do
          @urls.each { |url| assert_instance_of Bitly::Url, url }
        end
        should "return the user and global clicks for each url" do
          assert_equal 0, @urls[0].user_clicks
          assert_equal 67, @urls[0].global_clicks
          assert_equal 0, @urls[1].user_clicks
          assert_equal 0, @urls[1].global_clicks
        end
      end
    end
  end

  context "without valid credentials" do
    setup do
      @bitly = Bitly::Client.new('rubbish', 'wrong')
      stub_get(%r|http://api\.bit\.ly/v3/shorten?.*|, 'invalid_credentials.json')
    end
    should "raise an error on any call" do
      assert_raise BitlyError do
        @bitly.shorten('http://google.com')
      end
    end
  end
end
