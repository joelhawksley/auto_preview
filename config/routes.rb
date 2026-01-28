# frozen_string_literal: true

AutoPreview::Engine.routes.draw do
  get "/", to: "previews#index"
  get "show", to: "previews#show"
  get "component", to: "previews#component"
end
