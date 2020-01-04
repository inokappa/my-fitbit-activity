# Reference: https://qiita.com/Sa2Knight/items/f9b97335d4fa755c7dc0
#            https://dev.fitbit.com/build/reference/web-api/activity/#activity-types
#            https://dev.fitbit.com/build/reference/web-api/oauth2/#refreshing-tokens
#            https://docs.pixe.la/
require 'date'
require 'net/http'
require 'json'
require 'logger'

def logger
  Logger.new(STDOUT)
end

class FitBitAuth
  def token_active?(token)
    base_url = 'https://api.fitbit.com/1.1/oauth2/introspect'
    data = { 'token': token }
    res = fetch(base_url, data)
    res['active']
  end

  def refresh_token
    logger.warn('Get the Access Token again because the Access Token has expired.')
    base_url = 'https://api.fitbit.com/oauth2/token'
    data = { 'grant_type': 'refresh_token',
             'refresh_token': ENV['FITBIT_REFRESH_TOKEN'],
             'expires_in': 3600 }
    res = fetch(base_url, data)
    write_token('refresh', res['refresh_token']) if res.has_key?('refresh_token')
    write_token('access', res['access_token']) if res.has_key?('access_token')
    res['access_token'] if res.has_key?('access_token')
  end

  private

  def write_token(type, token)
    base_url = "https://circleci.com/api/v1.1/project/github/#{ENV['CIRCLE_PROJECT_USERNAME']}/#{ENV['CIRCLE_PROJECT_REPONAME']}/envvar"
    with_parameter = base_url + "?circle-token=#{ENV['CIRCLECI_PERSONAL_TOKEN']}"
    data = { 'name': 'FITBIT_REFRESH_TOKEN',
             'value': token }
    data['name'] = 'FITBIT_ACCESS_TOKEN' if type == 'access'
    p data['name']
    fetch(with_parameter, data)
    logger.info("Project Environment Variables `#{data['name']}` updated.")
  end

  def fetch(base_url, data)
    uri = URI.parse(base_url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    # [client_id]:[client_secret] encode to base64 = FITBIT_AUTH_STRING
    req['Authorization'] = "Basic #{ENV['FITBIT_AUTH_STRING']}"
    req['Content-Type'] = 'application/x-www-form-urlencoded'
    req.delete('Authorization') if base_url.include?('circleci.com') 
    req['Content-Type'] = 'application/json' if base_url.include?('circleci.com') 
    req.set_form_data(data)

    begin
      res = https.request(req)
      JSON.parse(res.body)
    rescue => ex
      Logger.error('Error: ' + ex.message)
      exit 1
    end
  end

end

class FitBitActivity
  def initialize(access_token, date)
    @base_url = 'https://api.fitbit.com/1/user/-'
    @request_header = { 'Authorization' => "Bearer #{access_token}" }
    @date = date
  end

  def method_missing(resource)
    send("fetch_resource", resource, @date)
  end

  private

  def fetch_error_handler(e)
    logger.error('Error: ' + e['errors'][0]['errorType'])
    exit 1
  end

  def fetch_resource(resource, date)
    activity_url = "#{@base_url}/activities/#{resource}/date/#{date}/1d.json"
    res = fetch(activity_url)
    return res["activities-#{resource}"][0]['value'] if res.has_key?("activities-#{resource}")
    fetch_error_handler(res) if res.has_key?('success')
  end
  
  def fetch(url)
    uri = URI.parse(url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Get.new(uri.request_uri, @request_header)
    begin
      res = https.request(req)
      JSON.parse(res.read_body)
    rescue => ex
      logger.error('Error: ' + ex)
      exit 1
    end
  end
end

class Pixela
  def initialize(graph, date)
    @base_url = "https://pixe.la/v1/users/#{ENV['PIXELA_USER_PATH']}/graphs/" + graph
    @date = date
  end

  def post(value)
    data = { 'date': @date, 'quantity': value.to_s }.to_json
    res = write(data)
    return res['message'] unless res['isSuccess']
    return 'Pixela posted.' if res['isSuccess']
  end

  private

  def write(data)
    uri = URI.parse(@base_url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req['X-USER-TOKEN'] = ENV['PIXELA_USER_TOKEN']
    req['Content-Type'] = 'application/json'
    req.body = data
    begin
      res = https.request(req)
      JSON.parse(res.body)
    rescue => ex
      puts 'Error: ' + ex.message
      exit 1
    end
  end
end

auth = FitBitAuth.new
access_token = ENV['FITBIT_ACCESS_TOKEN']

# logger.debug('Initial Access Token: ' + access_token)
access_token = auth.refresh_token unless auth.token_active?(access_token)
d = Date.today - 1
# logger.debug('Using Access Token: ' + access_token)
dis = FitBitActivity.new(access_token, d.strftime("%Y-%m-%d")).distance
logger.info('Distance(km): ' + dis)
res = Pixela.new(ENV['PIXELA_GRAPH'], d.strftime("%Y%m%d")).post(dis.to_i)
logger.info(res)
