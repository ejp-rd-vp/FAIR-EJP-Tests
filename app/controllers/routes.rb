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
    guid = payload['subject']
    begin
      @result = FAIRTest.send(id, **{ guid: guid })
    rescue StandardError
      @result = '{}'
    end
    @result.to_json
  end

  get '/tests/:id' do
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
