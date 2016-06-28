require_relative '../spec_helper'
require 'webmock/rspec'
require 'json'
require 'securerandom'
require 'pp'
require 'rspec/its'

RSpec.describe SonataCatalogue do

  def app
    @app ||= SonataCatalogue
  end

  $nsd_id

  describe 'GET \'/\'' do
    before do
      stub_request(:get, 'localhost:5000').to_return(status: 200)
      get '/'
    end
    subject { last_response }
    its(:status) { is_expected.to eq 200 }
  end

  let(:ns_descriptor) {Rack::Test::UploadedFile.new('./spec/fixtures/nsd-example.json','application/json', true)}
  describe 'POST \'/network-services\'' do
    context 'with correct parameters' do
      it 'Submit an nsd' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/network-services', ns_descriptor, headers
        expect(last_response.status).to eq(201)
        nsd_body = JSON.parse(last_response.body)
        $nsd_id = (nsd_body['uuid'])
      end
    end
  end

  let(:ns_descriptor) {Rack::Test::UploadedFile.new('./spec/fixtures/nsd-example.json','application/json', true)}
  describe 'POST \'/network-services\'' do
    context 'Duplicated nsd' do
      it 'Submit a duplicated nsd' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/network-services', ns_descriptor, headers
        expect(last_response.status).to eq(200)
      end
    end
  end

  let(:ns_bad_descriptor) {Rack::Test::UploadedFile.new('./spec/fixtures/nsd-example-with-errors.json','application/json', true)}
  describe 'POST \'/network-services-bad\'' do
    context 'with incorrect parameters' do
      it 'Submit an invalid nsd' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/network-services', ns_bad_descriptor, headers
        expect(last_response.status).to eq(400)
      end
    end
  end

  describe 'GET /network-services' do
    context 'without (UU)ID given' do
      before do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        get '/network-services', nil, headers
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

  describe 'GET /network-services/:uuid' do
    context 'with (UU)ID given' do
      before do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        get '/network-services/' + $nsd_id.to_s, nil, headers
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

  describe 'DELETE /network-services/:uuid' do
    context 'with (UU)ID given' do
      before do
        delete '/network-services/' + $nsd_id.to_s
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

end