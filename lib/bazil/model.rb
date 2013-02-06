require 'rubygems'
require 'json'
require 'bazil/error'

module Bazil
  class Model
    attr_reader :model_id, :config_id

    def initialize(client, model_id, config_id)
      @client = client
      @http_cli = client.http_client
      @model_id = model_id
      @config_id = config_id
    end

    def status
      res = @http_cli.get(gen_uri(target_path(@config_id, "status")))
      raise_error("Failed to get status of the model: #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def model_config
      res = @http_cli.get(gen_uri("config"))
      raise_error("Failed to get model config: #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def update_model_config(conf)
      res = send(:put, 'config', conf.to_json, "Failed to update model config")
      JSON.parse(res)
    end

    def config
      res = @http_cli.get(gen_uri("configs/#{@config_id}"))
      raise_error("Failed to get config of the model: #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def update_config(config)
      res = send(:put, "configs/#{@config_id}", config.to_json, "Failed to updated config")
      true
    end

    def train(annotation, data)
      raise ArgumentError, 'Annotation must be not nil' if annotation.nil?
      raise ArgumentError, 'Data must be not nil' if data.nil?

      new_data = {}
      new_data['annotation'] = annotation if annotation
      new_data['data'] = data if data
      new_data['config_id'] = @config_id
      body = post("training_data", new_data.to_json, "Failed to post training data")
      JSON.parse(body)
    end

    def retrain(option = {})
      body = post(target_path(@config_id, 'retrain'), option.to_json, "Failed to retrain the model")
      JSON.parse(body)
    end

    def trace(method, data, config = nil)
      new_data = {}
      new_data['method'] = method if method
      new_data['data'] = data if data
      new_data['config'] = config if config
      body = post(target_path(@config_id, "trace"), new_data.to_json, "Failed to execute trace")
      JSON.parse(body)
    end

    def evaluate(method, config)
      new_data = {}
      new_data['method'] = method if method
      new_data['config'] = config if config
      body = post(target_path(@config_id, "evaluate"), new_data.to_json, "Failed to execute evaluate")
      JSON.parse(body)
    end

    def labels
      res = @http_cli.get(gen_uri(target_path(@config_id, "labels")))
      raise_error("Failed to get labels the model has: #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)['labels']
    end

    def training_data(id)
      res = @http_cli.get(gen_uri("training_data/#{id}"))
      raise_error("Failed to get training data of the model: id = #{id}, #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def list_training_data(condition)
      # TODO: validate parameter
      condition = condition.dup
      condition[:page] ||= 1
      condition[:page_size] ||= 10
      condition[:query] ||= { :version => '1' }
      condition[:query][:version] = '1' unless condition[:query][:version]

      res = post("training_data/query?page=#{condition[:page]}&page_size=#{condition[:page_size]}",
                 condition[:query].to_json, "Failed to query training data of the model")
      JSON.parse(res)
    end

    def clear_training_data
      res = @http_cli.delete(gen_uri("training_data"))
      raise_error("Failed to clear training_data of the model: #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      true
    end

    def put_training_data(annotation, data)
      new_data = {}
      new_data['annotation'] = annotation if annotation
      new_data['data'] = data if data
      new_data['config_id'] = @config_id
      body = post('training_data', new_data.to_json, "Failed to post training data")
      JSON.parse(body)
    end

    def update_training_data(id, annotation, data)
      # TODO: type check of id
      new_data = {}
      new_data['annotation'] = annotation if annotation
      new_data['data'] = data if data
      new_data['config_id'] = @config_id
      send(:put, "training_data/#{id}", new_data.to_json, "Failed to update training data")
      true
    end

    def delete_training_data(id)
      # TODO: type check of id
      res = @http_cli.delete(gen_uri("training_data/#{id}"))
      raise_error("Failed to delete a training data: id = #{id}, #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      true
    end

    def query(data)
      data = {'data' => data}.to_json
      res = post(target_path(@config_id, 'query'), data, "Failed to post data for query")
      JSON.parse(res)
    end

    private

    def post(path, data, error_message)
      send(:post, path, data, error_message)
    end

    def send(method, path, data, error_message)
      res = @http_cli.method(method).call(gen_uri(path), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise_error("#{error_message}: #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/ # TODO: enhance error information
      res.body
    end

    def target_path(id, path)
      "configs/#{id}/#{path}"
    end

    def gen_uri(path = nil)
      if path
        "/#{@client.api_version}/models/#{@model_id}/#{path}"
      else
        "/#{@client.api_version}/models/#{@model_id}"
      end
    end

    def error_suffix
      "model = #{@model_id}"
    end

    def raise_error(message, res)
      raise APIError.new(message, res.code, JSON.parse(res.body))
    end
  end # module Model
end # module Bazil
