# frozen_string_literal: true

AutoPreview::Engine.routes.draw do
  get "previews/show", to: "previews#show"
end
