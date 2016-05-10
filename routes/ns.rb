require 'addressable/uri'
require 'pp'
require 'json'

# This Class is the Class of Sonata Ns Repository
class SonataNsRepository < Sinatra::Application
  @@nsr_schema = JSON.parse(JSON.dump(YAML.load(open('https://raw.githubusercontent.com/sonata-nfv/son-schema/master/service-record/nsr-schema.yml') { |f| f.read })))

  DEFAULT_OFFSET = '0'
  DEFAULT_LIMIT = '10'
  DEFAULT_MAX_LIMIT = '100'

  # @method get_root
  # @overload get '/'
  get '/' do
    headers 'Content-Type' => 'text/plain; charset=utf8'
    halt 200, interfaces_list.to_yaml
  end

  # @method get_ns-instances
  # @overload get "/ns-instances"
  # Gets all ns-instances
  get '/ns-instances' do
    uri = Addressable::URI.new
    params['offset'] ||= DEFAULT_OFFSET
    params['limit'] ||= DEFAULT_LIMIT
    uri.query_values = params
    logger.info "nsr: entered GET /records/nsr/ns-instances?#{uri.query}"

    # transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)

    # Get paginated list
    headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    headers[:params] = params unless params.empty?
    # get rid of :offset and :limit
    [:offset, :limit].each { |k| keyed_params.delete(k) }
    valid_fields = [:page]
    logger.info "nsr: keyed_params.keys - valid_fields = #{keyed_params.keys - valid_fields}"
    json_error 400, "nsr: wrong parameters #{params}" unless keyed_params.keys - valid_fields == []

    requests = Nsr.paginate(:page => params[:page], :limit => params[:limit])
    logger.info "nsr: leaving GET /requests?#{uri.query} with #{requests.to_json}"
    halt 200, requests.to_json if requests
    json_error 404, 'nsr: No requests were found'

    begin
      # Get paginated list
      nsr_json = @nsr.to_json
      if content_type == 'application/json'
        return 200, nsr_json
      elsif content_type == 'application/x-yaml'
        headers 'Content-Type' => 'text/plain; charset=utf8'
        nsr_yml = json_to_yaml(nsr_json)
        return 200, nsr_yml
      end
    rescue
      logger.error 'Error Establishing a Database Connection'
      return 500, 'Error Establishing a Database Connection'
    end
  end

  # @method get_ns-instances
  # @overload get "/ns-instances"
  # Gets ns-instances with an id
  get '/ns-instances/:id' do
    begin
      @nsinstance = Nsr.find(params[:id])
    rescue Mongoid::Errors::DocumentNotFound => e
      halt(404)
    end
    nsr_json = @nsinstance.to_json
    return 200, nsr_json
  end

  # @method post_ns-instances
  # @overload post "/ns-instances"
  # Post a new ns-instances information
  post '/ns-instances' do
    return 415 unless request.content_type == 'application/json'
    # Validate JSON format
    instance, errors = parse_json(request.body.read)
    nsr_json = instance
    return 400, errors.to_json if errors
    # Validation against schema
    errors = validate_json(nsr_json, @@nsr_schema)

    puts 'nsr: ', Nsr.to_json
    return 422, errors.to_json if errors

    begin
      instance = Nsr.find({ '_id' => instance['_id'] })
      return 409, 'ERROR: Duplicated NS ID'
    rescue Mongoid::Errors::DocumentNotFound => e
    end

    begin
      instance = Nsr.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 409, 'ERROR: Duplicated NS ID'
    end
    return 200, instance.to_json
  end

  # @method put_ns-instances
  # @overload put "/ns-instances"
  # Puts a ns-instances record
  put '/ns-instances/:id' do
    # Return if content-type is invalid
    415 unless request.content_type == 'application/json'
    # Validate JSON format
    instance, errors = parse_json(request.body.read)
    return 400, errors.to_json if errors
    # Retrieve stored version
    new_nsr = instance
    
    # Validation against schema
    errors = validate_json(nsr_json, @@nsr_schema)

    puts 'nsr: ', Nsr.to_json
    return 422, errors.to_json if errors

    begin
      nsr = Nsr.find_by('_id' => params[:id])
      puts 'NS is found'
    rescue Mongoid::Errors::DocumentNotFound => e
      return 400, 'This NSD does not exists'
    end

    # Update to new version
    puts 'Updating...'
    begin
      # Delete old record
      Nsr.where('_id' => params[:id]).delete
      # Create a record
      new_nsr = Nsr.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 409, 'ERROR: Duplicated NS ID'
    end

    nsr_json = new_nsr.to_json
    return 200, nsr_json
    # return 200, new_ns.to_json
  end

  delete '/ns-instances/:id' do
    # Return if content-type is invalid
    begin
      nsr = Nsr.find_by('_id' => params[:id])
      puts 'NS is found'
    rescue Mongoid::Errors::DocumentNotFound => e
      return 400, 'This NSD does not exists'
    end

    # Delete the nsr
    puts 'Deleting...'
    begin
      # Delete the network service record
      Nsr.where('_id' => params[:id]).delete
    end

    return 200
    # return 200, new_ns.to_json
  end
end
