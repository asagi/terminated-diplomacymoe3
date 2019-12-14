Rails.application.routes.draw do
  resources :users, except: [ :index ]

  get '/login/:provider',         to: 'sessions#login'
  get '/auth/:provider/callback', to: 'sessions#create'
  get '/auth/failure',            to: 'sessions#failure'
  get '/logout',                  to: 'sessions#destroy'

end