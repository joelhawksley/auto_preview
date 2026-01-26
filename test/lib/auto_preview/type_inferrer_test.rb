# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class TypeInferrerTest < ActiveSupport::TestCase
    def test_infer_predicate
      type, value = TypeInferrer.infer("active?")
      assert_equal "Boolean", type
      assert_equal "true", value
    end

    def test_infer_boolean_prefix_patterns
      type, value = TypeInferrer.infer("is_active")
      assert_equal "Boolean", type
      assert_equal "true", value

      type, _ = TypeInferrer.infer("has_permission")
      assert_equal "Boolean", type

      type, _ = TypeInferrer.infer("can_edit")
      assert_equal "Boolean", type

      type, _ = TypeInferrer.infer("show_details")
      assert_equal "Boolean", type

      type, _ = TypeInferrer.infer("active_subscription")
      assert_equal "Boolean", type
    end

    def test_infer_integer_suffix_patterns
      type, value = TypeInferrer.infer("user_id")
      assert_equal "Integer", type
      assert_equal "42", value

      type, _ = TypeInferrer.infer("item_count")
      assert_equal "Integer", type

      type, _ = TypeInferrer.infer("age")
      assert_equal "Integer", type

      type, _ = TypeInferrer.infer("index")
      assert_equal "Integer", type
    end

    def test_infer_float_suffix_patterns
      type, value = TypeInferrer.infer("unit_price")
      assert_equal "Float", type
      assert_equal "19.99", value

      type, _ = TypeInferrer.infer("tax_rate")
      assert_equal "Float", type

      type, _ = TypeInferrer.infer("conversion_ratio")
      assert_equal "Float", type
    end

    def test_infer_date_patterns
      type, value = TypeInferrer.infer("created_at")
      assert_equal "String", type
      assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, value)

      type, _ = TypeInferrer.infer("published_on")
      assert_equal "String", type

      type, _ = TypeInferrer.infer("birth_date")
      assert_equal "String", type
    end

    def test_infer_url_patterns
      type, value = TypeInferrer.infer("profile_url")
      assert_equal "String", type
      assert_equal "https://example.com", value

      type, _ = TypeInferrer.infer("website_link")
      assert_equal "String", type
    end

    def test_infer_email_patterns
      type, value = TypeInferrer.infer("user_email")
      assert_equal "String", type
      assert_equal "user@example.com", value
    end

    def test_infer_name_patterns
      type, value = TypeInferrer.infer("user_name")
      assert_equal "String", type
      assert_includes value, "Example"

      type, _ = TypeInferrer.infer("page_title")
      assert_equal "String", type
    end

    def test_infer_text_patterns
      type, value = TypeInferrer.infer("post_description")
      assert_equal "String", type
      assert_includes value, "sample"

      type, _ = TypeInferrer.infer("article_body")
      assert_equal "String", type

      type, _ = TypeInferrer.infer("main_content")
      assert_equal "String", type
    end

    def test_infer_array_patterns
      type, value = TypeInferrer.infer("cart_items")
      assert_equal "Array", type
      assert_equal "[]", value

      type, _ = TypeInferrer.infer("tag_list")
      assert_equal "Array", type
    end

    def test_infer_hash_patterns
      type, value = TypeInferrer.infer("user_data")
      assert_equal "Hash", type
      assert_equal "{}", value

      type, _ = TypeInferrer.infer("app_config")
      assert_equal "Hash", type

      type, _ = TypeInferrer.infer("query_params")
      assert_equal "Hash", type
    end

    def test_infer_user_patterns_with_factory
      type, value = TypeInferrer.infer("current_user")
      assert_equal "Factory", type
      assert_equal "user", value

      type, _ = TypeInferrer.infer("admin")
      assert_equal "Factory", type
    end

    def test_infer_user_patterns_without_factory
      original_factory_bot = Object.send(:remove_const, :FactoryBot)
      begin
        type, value = TypeInferrer.infer("current_user")
        assert_equal "String", type
        assert_equal "John Doe", value
      ensure
        Object.const_set(:FactoryBot, original_factory_bot)
      end
    end

    def test_infer_default_string
      type, value = TypeInferrer.infer("random_thing")
      assert_equal "String", type
      assert_includes value, "Sample"
    end

    def test_infer_factory_match
      type, value = TypeInferrer.infer("user")
      assert_equal "Factory", type
      assert_equal "user", value
    end
  end
end
