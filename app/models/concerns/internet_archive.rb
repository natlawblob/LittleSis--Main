require 'net/http'

module InternetArchive

  def save_url_to_archive
    uri = URI(ia_save_link)
    Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
      request = Net::HTTP::Get.new(uri)
      response = http.request(request)
      case response
      when Net::HTTPRedirection then
        puts response['Content-Location']
      else
        puts "Failed to save url"
      end
    end
  end

  private

  def ia_save_link
    "https://web.archive.org/save/#{source}"
  end

end
