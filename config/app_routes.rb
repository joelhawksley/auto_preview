# frozen_string_literal: true

Rails.application.routes.draw do
  mount AutoPreview::Engine => "/auto_preview"
  root to: redirect("/auto_preview")
end
