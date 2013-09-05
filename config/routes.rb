Spree::Core::Engine.routes.draw do

  resources :orders do
    resource :checkout, :controller => 'checkout' do
      member do
        get :sermepa_checkout
        get :sermepa_payment
      end
    end

    resource :sermepa_callbacks, :controller => 'sermepa_callbacks' do
      member do
        post :sermepa_notify
        get :sermepa_notify
        get :sermepa_confirm
        post :sermepa_confirm
      end
    end

    resource :ceca_callbacks, :controller => 'ceca_callbacks' do
      member do
        get :ceca_confirm
        post :ceca_confirm
      end
    end

  end

  match '/ceca_notify' => 'ceca_callbacks#ceca_notify', :via => [:get, :post]

end



