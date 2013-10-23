require File.expand_path('../test_helper', __FILE__)

module Inquisitio
  class SearcherTest < Minitest::Test
    def setup
      super
      @search_endpoint = 'http://my.search-endpoint.com'
      Inquisitio.config.search_endpoint = @search_endpoint
      @expected_result_1 = {'id' => 1, 'title' => "Foobar", 'type' => "cat"}
      @expected_result_2 = {'id' => 2, 'title' => "Foobar2", 'type' => "dog"}
      @expected_results = [@expected_result_1, @expected_result_2]

      body = <<-EOS
      {"rank":"-text_relevance","match-expr":"(label 'star wars')","hits":{"found":2,"start":0,"hit":#{@expected_results.to_json}},"info":{"rid":"9d3b24b0e3399866dd8d376a7b1e0f6e930d55830b33a474bfac11146e9ca1b3b8adf0141a93ecee","time-ms":3,"cpu-time-ms":0}}
      EOS

      Excon.defaults[:mock] = true
      Excon.stub({}, {body: body, status: 200})
    end

    def teardown
      super
      Excon.stubs.clear
    end

    def test_initialization_with_string
      filters = { :genre => [ 'Animation' ] }
      return_fields = [ 'title' ]
      searcher = Searcher.new('Star Wars', filters.merge({return_fields: return_fields}))
      assert_equal 'Star Wars', searcher.instance_variable_get("@query")
      assert_equal filters, searcher.instance_variable_get("@filters")
      assert_equal return_fields, searcher.instance_variable_get("@return_fields")
    end

    def test_initialization_with_hash
      filters = { :genre => [ 'Animation' ] }
      return_fields = [ 'title' ]
      searcher = Searcher.new(filters.merge({return_fields: return_fields}))
      assert_equal nil, searcher.instance_variable_get("@query")
      assert_equal filters, searcher.instance_variable_get("@filters")
      assert_equal return_fields, searcher.instance_variable_get("@return_fields")
    end

    def test_searcher_should_raise_exception_if_query_null
      assert_raises(InquisitioError, "Query is nil") do
        Searcher.search(nil)
      end
    end


    def test_search_raises_exception_when_response_not_200
      Excon.stub({}, {:body => 'Bad Happened', :status => 500})

      searcher = Searcher.new('Star Wars')

      assert_raises(InquisitioError, "Search failed with status code 500") do
        searcher.search
      end
    end

    def test_search_should_set_results
      searcher = Searcher.new('Star Wars', { :return_fields => [ 'title', 'year', '%' ] } )
      searcher.search
      assert_equal @expected_results, searcher.instance_variable_get("@results")
    end

    def test_search_should_set_ids
      searcher = Searcher.new('Star Wars', { :return_fields => [ 'title', 'year', '%' ] } )
      searcher.search
      assert_equal @expected_results.map{|r|r['id']}, searcher.ids
    end

    def test_search_should_set_records
      searcher = Searcher.new('Star Wars', { :return_fields => [ 'title', 'year', '%' ] } )
      searcher.search

      # [{"MediaFile" => 1}, {...}]
      records = []
      records << {@expected_result_1['type'] => @expected_result_1['id']}
      records << {@expected_result_2['type'] => @expected_result_2['id']}
      assert_equal records, searcher.records
    end

########################
## URL CHECKING STUFF ##
########################

    def test_create_correct_search_url_without_return_fields
      searcher = Searcher.new('Star Wars')
      expected_url = 'http://my.search-endpoint.com/2011-02-01/search?q=Star%20Wars'
      assert_equal expected_url, searcher.send(:search_url)
    end

    def test_create_correct_search_url_including_return_fields
      searcher = Searcher.new('Star Wars', { :return_fields => [ 'title', 'year', '%' ] } )
      expected_url = 'http://my.search-endpoint.com/2011-02-01/search?q=Star%20Wars&return-fields=title,year,%25'
      assert_equal expected_url, searcher.send(:search_url)
    end
    def test_create_boolean_query_search_url_with_only_filters
      searcher = Searcher.new(title: 'Star Wars')
      expected_url = 'http://my.search-endpoint.com/2011-02-01/search?bq=(and%20title:\'Star%20Wars\')'
      assert_equal expected_url, searcher.send(:search_url)
    end

    def test_create_boolean_query_search_url_with_query_and_filters
      searcher = Searcher.new('Star Wars', genre: 'Animation')
      expected_url = 'http://my.search-endpoint.com/2011-02-01/search?bq=(and%20\'Star%20Wars\'%20genre:\'Animation\')'
      assert_equal expected_url, searcher.send(:search_url)
    end

    def test_create_boolean_query_search_url_with_query_and_filters_and_return_fields
      searcher = Searcher.new('Star Wars', {genre: 'Animation', :return_fields => [ 'title', 'year', '%' ] } )
      expected_url = 'http://my.search-endpoint.com/2011-02-01/search?bq=(and%20\'Star%20Wars\'%20genre:\'Animation\')&return-fields=title,year,%25'
      assert_equal expected_url, searcher.send(:search_url)
    end

    def test_create_search_url_with_added_arguments
      searcher = Searcher.new('Star Wars', {genre: 'Animation', :arguments => { facet: 'genre', 'facet-genre-constraints' => 'Animation', 'facet-genre-top-n' => '5'} } )
      expected_url = 'http://my.search-endpoint.com/2011-02-01/search?bq=(and%20\'Star%20Wars\'%20genre:\'Animation\')&facet=genre&facet-genre-constraints=Animation&facet-genre-top-n=5'
      assert_equal expected_url, searcher.send(:search_url)
    end
  end
end