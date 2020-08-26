require "metapage/version"
require 'nokogiri'
require 'httpclient'
require 'uri'
require 'resolv'
require 'ipaddr'
require 'digest/sha1'
require 'mimemagic'

module Metapage
  class ResolveError < StandardError; end;
  class HTTPResponseError < StandardError; end;
  class ContentTypeError < StandardError; end;
  class IgnoredTitleError < StandardError; end;
  ERROR_CLASSES = [ResolveError, HTTPResponseError, ContentTypeError, IgnoredTitleError]

  IGNORE_LIST = ["signup", "signin", "login", "anmeldung", "anmelden", "registration"]

  class << self
    def fetch(url)
      fetch! url
    rescue *ERROR_CLASSES => err
      nil
    end

    def fetch!(url)
      Metadata.new(url)
    end

    def extract(text)
      extract_urls(text).map {|url| fetch(url.gsub(/[\.\,]+\Z/, '')) }.compact
    end

    def extract!(text)
      extract_urls(text).map {|url| fetch!(url.gsub(/[\.\,]+\Z/, '')) }.compact
    end

    def extract_urls(text)
      processed_text = text.
        gsub(/([^\/])www\./, '\1http://www.').
        gsub(/\Awww\./, 'http://www.')
      URI.extract processed_text, ['http', 'https']
    end
  end

  class Metadata
    attr_reader :url
    def initialize(url)
      @url = url
      title
    end

    def title
      unless image?
        @title ||= (metatag_content('og:title') || html_content('title')).tap do |title|
          if title
            checked_title = title.downcase.gsub(' ', '')
            if IGNORE_LIST.any? {|word| checked_title.include? word }
              raise IgnoredTitleError
            end
          end
        end
      end
    end

    def description
      unless image?
        @description ||= metatag_content('og:description') || metatag_content('description')
      end
    end

    def image_url
      if image?
        url
      else
        # Fallback to apple-touch-icon, fluid-icon, ms-tileicon etc
        @image_url ||= metatag_content('og:image:secure_url') || metatag_content('og:image') || link_rel('apple-touch-icon')
      end
    end

    def type
      if image?
        'image'
      else
        @type ||= metatag_content('og:type') || 'website'
      end
    end

    def canonical_url
      if image?
        url
      else
        @canonical_url ||= metatag_content('og:url') || link_rel('canonical') || url
      end
    end

    def id
      if canonical_url
        @id ||= Digest::SHA1.hexdigest(canonical_url)
      end
    end

    def site_name
      unless image?
        @site_name ||= metatag_content('og:site_name') || host
      end
    end

    def media_type
      mimemagic and mimemagic.mediatype
    end

    def content_type
      mimemagic and mimemagic.type
    end

    def to_h
      {
        id: id,
        title: title,
        description: description,
        image_url: image_url,
        type: type,
        canonical_url: canonical_url,
        site_name: site_name,
        media_type: media_type,
        content_type: content_type
      }
    end

    def to_json
      to_h.to_json
    end

    private

      def uri
        @uri ||= URI(canonical_url)
      end

      def host
        @host ||= uri.host
      end

      def scheme
        @scheme ||= uri.scheme
      end

      def absolute_url(href)
        if href.start_with?('http')
          href
        else
          scheme + '://' + File.join(host, href)
        end
      end

      def link_rel(rel)
        if tag = doc.css('link[rel="'+rel+'"]').first
          absolute_url tag['href']
        else
          nil
        end
      end

      def metatag_content(tag_name)
        if tag = doc.css('meta[property="'+ tag_name +'"]').first
          tag["content"]
        elsif tag = doc.css('meta[name="'+ tag_name +'"]').first
          tag["content"]
        end
      end

      def html_content(selector)
        if tag = doc.css(selector).first
          tag.text
        end
      end

      def doc
        @doc ||= Nokogiri::HTML.parse(content).tap do |doc|
          raise ContentTypeError, "Document does not seem to be valid html" if doc.css('div').empty?
        end
      end

      def image?
        media_type == 'image'
      end

      def mimemagic
        @mimemagic ||= MimeMagic.by_magic(content)
      end

      def content
        http_response.body
      end

      def http_response
        begin
          raise Metapage::HTTPResponseError, "Invalid scheme for #{url}" unless valid_scheme?
          raise Metapage::ResolveError, "Could not find any DNS records for #{url}" unless valid_dns?
        rescue ArgumentError
          raise Metapage::ResolveError, "Cannot parse url #{url.inspect}"
        end

        @http_response ||= begin
          http_client.get(url, follow_redirect: true).tap do |response|
            unless (200..299).include? response.status
              raise Metapage::HTTPResponseError, "Invalid response status #{response.status}"
            end
          end
        end
      rescue SocketError, HTTPClient::ReceiveTimeoutError => err
        raise Metapage::HTTPResponseError, err.to_s
      end

      def valid_scheme?
        %w(http https).include? URI(url).scheme
      end

      def valid_dns?
        dns = Resolv::DNS.new(nameserver: ['8.8.8.8', '8.8.4.4'])
        address = dns.getaddress(URI(url).host).to_s
        not private_subnets.any? {|net| net.include? IPAddr.new(address) }
      rescue Resolv::ResolvError
        false
      end

      def private_subnets
        @private_subnets ||= ['127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'].map {|cidr| IPAddr.new cidr }
      end

      def http_client
        http_client ||= HTTPClient.new.tap do |http_client|
          http_client.receive_timeout = 3
          http_client.connect_timeout = 3
          http_client.send_timeout = 3
          http_client.keep_alive_timeout = 3
          http_client.ssl_config.timeout = 3
        end
      end
  end
end
