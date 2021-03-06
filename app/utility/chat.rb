# frozen_string_literal: true

require 'net/http'

class Chat
  API_URL = APP_CONFIG['chat']['api_url']
  USERNAME = APP_CONFIG['chat']['admin_username']
  PASSWORD = APP_CONFIG['chat']['admin_password']

  class RocketChatApiRequestFailedError < StandardError
  end

  def initialize
    @admin_token = nil
    @admin_id = nil
  end

  def create_user(user)
    return nil if user.chatid.present?
    res = post '/api/v1/users.create', user_payload(user), auth_headers
    res_success?(res)
    mongo_chat_id = res['user']['_id']
    user.update!(chatid: mongo_chat_id)
  end

  def login_token(mongo_id)
    res = post '/api/v1/users.createToken', { userId: mongo_id }, auth_headers
    res_success?(res)
    { 'loginToken' => res['data']['authToken'] }
  end

  def info
    get '/api/v1/info'
  end

  def admin_login
    res = post '/api/v1/login', username: USERNAME, password: PASSWORD
    if res.present? && res.fetch('status', '') == 'success'
      @admin_token = res['data'].fetch('authToken')
      @admin_id = res['data'].fetch('userId')
    end
  end

  def admin_logout
    res = get '/api/v1/logout', auth_headers
    if res
      @admin_token = nil
      @admin_id = nil
    end
  end

  ##  CLASS METHODS  ##

  def self.create_user(user)
    api_request { |chat| chat.create_user(user) }
  end

  def self.login_token(mongo_id)
    api_request { |chat| chat.login_token(mongo_id) }
  end

  def self.api_request
    chat = new
    chat.admin_login
    begin
      yield(chat)
    ensure
      chat.admin_logout
    end
  end

  private

  def auth_headers
    { 'X-Auth-Token' => @admin_token, 'X-User-Id' => @admin_id }
  end

  def user_payload(user)
    {
      'email' => user.email,
      'name' => user.username,
      'password' => SecureRandom.urlsafe_base64(20),
      'username' => user.username,
      'verified' => true
    }
  end

  # str, hash, hash => json | nil
  def post(route, data, headers = nil)
    uri = path_to_uri route
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    add_headers(req, headers) unless headers.blank?
    req.body = data.to_json
    success_check Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
  end

  def get(route, headers = nil)
    uri = path_to_uri route
    req = Net::HTTP::Get.new(uri)
    add_headers(req, headers) unless headers.blank?
    success_check(Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) })
  end

  def add_headers(req, headers)
    headers.each { |key, val| req[key] = val }
  end

  # str -> <URI>
  def path_to_uri(path)
    URI("#{API_URL}#{path}")
  end

  # This checks if the status of the request returned by RocketChat
  # is not of status 'success'
  def res_success?(res)
    return true if ['success', true].include?(res&.fetch('status', false))
    return true if ['success', true].include?(res&.fetch('success', false))
    Rails.logger.info 'RocketChat API request failed'
    Rails.logger.info res
    raise RocketChatApiRequestFailedError
  end

  # This checks if the HTTP request fails (i.e. did not return 200)
  # Might happen if RocketChat is down
  # <NetResponce> -> json | nil
  def success_check(res)
    return JSON.parse(res.body) if res.is_a?(Net::HTTPSuccess)
    Rails.logger.debug "Chat API request failed: #{res.inspect}"
    Rails.logger.debug "Failed response: #{res.body}"
    nil
  end
end
