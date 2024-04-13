# frozen_string_literal: false

def set_routes(classes: allclasses)
  set :server_settings, timeout: 180
  set :public_folder, 'public'

  get '/' do
    redirect '/tests/list'
  end

  get '/tests/' do
    content_type :json
    response.body = JSON.dump(Swagger::Blocks.build_root_json(classes))
  end

  get '/tests/list' do
    erb :listtests
  end
  post '/tests/:id' do
    content_type :json
    id = params[:id]
    payload = JSON.parse(request.body.read)
    guid = payload['subject'] ? payload['subject'] : params[:subject]
    begin
      @result = FAIRTest.send(id, **{ guid: guid })
    rescue StandardError
      @result = '{}'
    end

    request.accept.each do |type|
      case type.to_s
      when 'text/html'
        halt erb :testoutput
      when 'text/json', 'application/json', 'application/ld+json'
        halt @result
      end
    end
    error 406
  end

  get '/tests/:id' do
    id = params[:id]

    if params[:subject]
      @guid = params[:subject] if params[:subject]
      begin
        @result = FAIRTest.send(id, **{ guid: @guid })
      rescue StandardError
        warn "sending #{@guid} to test #{id} failed\n"
        @result = '{}'
      end
  
      request.accept.each do |type|
        case type.to_s
        when 'text/html'
          content_type :html
          halt erb :testoutput
        when 'text/json', 'application/json', 'application/ld+json'
          content_type :json
          halt @result
        end
      end
      halt error 406
    end
    content_type 'application/openapi+yaml'
    id = params[:id]
    id += '_api'
    begin
      @result = FAIRTest.send(id)
    rescue StandardError
      @result = ''
    end
    @result
  end

  before do
  end
end
