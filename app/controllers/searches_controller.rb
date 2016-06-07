class SearchesController < ApplicationController

  before_filter :set_search_service
  before_filter :set_search, only: [:show]

  def index
  end

  def new
    # Rendering advanced search form
    @title = 'Advanced search'
    @search = Search.new
    @nodes = []
  end

  def create
    @search = Search.new(key_words: params[:id])
    @search.title = 'Advanced search'
    if @search.save
      redirect_to @search
    else
      puts 'search failed !'
      render :new
    end
  end

  def show
    @title = @search.title
    @nodes = @search.advanced_search(@search.key_words, params)
    set_sidebar :tags, @search.key_words
  end

  def normal_search
    @title = 'Search'
    @tagnames = params[:id].split(',')
    @users = @search_service.users(params[:id])
    set_sidebar :tags, [params[:id]]

    @notes = DrupalNode.paginate(page: params[:page])
                 .order('node.nid DESC')
                 .where('(type = "note" OR type = "page" OR type = "map") AND node.status = 1 AND (node.title LIKE ? OR node_revisions.title LIKE ? OR node_revisions.body LIKE ?)', "%"+params[:id]+"%","%"+params[:id]+"%","%"+params[:id]+"%")
                 .includes(:drupal_node_revision)
  end

  # utility response to fill out search autocomplete
  # needs *dramatic* optimization

  def typeahead
    @match = @search_service.type_ahead(params[:id])
    render json: @match
  end

  def questions
    @title = 'Search questions'
    @tagnames = params[:id].split(',')
    @users = @search_service.users(params[:id])
    set_sidebar :tags, [params[:id]]
    @notes = DrupalNode.where('type = "note" AND node.status = 1 AND title LIKE ?', '%' + params[:id] + '%')
                 .joins(:drupal_tag)
                 .where('term_data.name LIKE ?', 'question:%')
                 .order('node.nid DESC')
                 .page(params[:page])
    if @notes.empty?
      session[:title] = params[:id]
      redirect_to '/post?tags=question:question&template=question&title='+params[:id]+'&redirect=question'
    else
      render :template => 'search/index'
    end
  end

  def questions_typeahead
    matches = []
    questions = DrupalNode.where('type = "note" AND node.status = 1 AND title LIKE ?', '%' + params[:id] + '%')
                    .joins(:drupal_tag)
                    .where('term_data.name LIKE ?', 'question:%')
                    .order('node.nid DESC')
                    .limit(25)
    questions.each do |match|
      matches << "<i data-url='"+match.path(:question)+"' class='fa fa-question-circle'></i> "+match.title
    end
    render :json => matches
  end

  def map
    @users = DrupalUsers.where("lat != 0.0 AND lon != 0.0")
  end

  private

    def set_search
      @search = Search.find(params[:id])
    end

    def set_search_service
      @search_service = SearchService.new
    end

    def search_params
      params.require(:search).permit(:comments, :maps, :wikis, :notes)
    end

end