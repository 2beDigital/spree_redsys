Spree::Core::Engine.routes.draw do

  resources :orders do
    resource :checkout, :controller => 'checkout' do
      member do
        get :sermepa_checkout
        get :sermepa_payment
        get :sermepa_confirm
        post :sermepa_notify
      end
    end
  end
end



