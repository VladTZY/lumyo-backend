Rails.application.routes.draw do
  devise_for :users,
    path: "",
    path_names: {
      sign_in: "login",
      sign_out: "logout",
      registration: "signup"
    },
    controllers: {
      sessions: "users/sessions",
      registrations: "users/registrations"
    }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  resource :autocategorize_all, only: [ :create ], controller: "autocategorize_all"
  resources :categories, only: [ :index, :show, :create, :update, :destroy ]
  resources :chats, only: [ :index, :show, :create, :update, :destroy ] do
    resources :messages, only: [ :create ]
  end
  resources :notes, only: [ :index, :show, :create, :update, :destroy ] do
    resource :summary, only: [ :show, :create ], controller: "note_summaries"
    resource :autocategorize, only: [ :create ], controller: "note_autocategorize"
  end

  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
