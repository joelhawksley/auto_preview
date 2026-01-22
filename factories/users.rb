# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    name { "John Doe" }
    email { "john@example.com" }

    trait :admin do
      name { "Admin User" }
      email { "admin@example.com" }
    end
  end
end
