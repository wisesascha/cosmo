class PagesController < ApplicationController

  layout 'main'

  def index
    list
    render(:action => 'list')
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

   def list
    @pages = Page.find(:all)
  end

  def show
    @page = Page.find(params[:id])
  end

  def new
    @page = Page.new
    finduserlist
  end

  def create
    @page = Page.new(params[:page])
    if @page.save
      flash[:notice] = 'Page was successfully created.'
      redirect_to(:action => 'list')
    else
      render(:action => 'new')
    end
  end

  def edit
    @page = Page.find(params[:id])
    finduserlist
  end

  def update
    @page = Page.find(params[:id])
    if @page.update_attributes(params[:page])
      flash[:notice] = 'Page was successfully updated.'
      redirect_to(:action => 'show', :id => @page.id)
    else
      render(:action => 'edit')
    end
  end

  def destroy
    Page.find(params[:id]).destroy
    redirect_to(:action => 'list')
  end
  private
    def finduserlist
        @user_list = User.find(:all).collect {|user| [link_to(user.full_name), user.id]}
    end
end
