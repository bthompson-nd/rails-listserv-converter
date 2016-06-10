class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  #Exposes session and flash hashes to service layer
  before_filter {
    Thread.current[:session] = session
    Thread.current[:flash] = flash
  }
  #Cleans current thread and redirects to friendly error page.
  after_filter{ |controller |
      Thread.current[:session] = nil
      Thread.current[:flash] = nil
      if flash.key?('error') and controller.controller_name != 'listservlists' and controller.action_name != 'index'
        response.location = url_for(:only_path => false, :controller => 'listservlists', :action  => 'index')
      end
  }

  rescue_from ActionView::MissingTemplate do |exception|
    flash[:error] ||= exception.message
    redirect_to(:only_path => false, :controller => 'listservlists', :action  => 'index')
  end
end
