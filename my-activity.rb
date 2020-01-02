# Reference: https://qiita.com/Sa2Knight/items/f9b97335d4fa755c7dc0
#            https://dev.fitbit.com/build/reference/web-api/activity/#activity-types
#            https://docs.pixe.la/
require 'date'
require 'net/http'
require 'json'

class FitBitActivity
  def initialize(date)
    @base_url = 'https://api.fitbit.com/1/user/-'
    @request_header = { 'Authorization' => "Bearer #{ENV['FITBIT_ACCESS_TOKEN']}" }
    @date = date
  end

  def method_missing(resource)
    send("fetch_resource", resource, @date)
  end

  private

  def fetch_resource(resource, date)
    activity_url = "#{@base_url}/activities/#{resource}/date/#{date}/1d.json"
    res = fetch(activity_url)
    res["activities-#{resource}"][0]['value']
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
      puts 'Error: ' + ex
      exit 1
    end
  end
end

class Pixela
  def initialize(graph, date)
    @base_url = 'https://pixe.la/v1/users/inokappa/graphs/' + graph
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
      JSON.parse(res.read_body)
    rescue => ex
      puts 'Error: ' + ex
      exit 1
    end
  end
end

d = Date.today - 1
dis = FitBitActivity.new(d.strftime("%Y-%m-%d")).distance
p dis
# puts Pixela.new('my-test-graph1', d.strftime("%Y%m%d")).post(dis.to_i)
