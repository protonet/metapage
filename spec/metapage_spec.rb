require 'spec_helper'

describe Metapage, vcr: { cassette_name: 'fetch' } do
  it 'has a version number' do
    expect(Metapage::VERSION).not_to be nil
  end

  def self.expect(attribute, value)
    it "has #{attribute} #{value.inspect}" do
      expect(result.send(attribute)).to be == value
    end

    it "contains #{attribute} in to_json variant" do
      expect(result.to_h[attribute]).to be == value
    end

    it "contains #{attribute} in to_json variant" do
      expect(JSON.load(result.to_json)[attribute.to_s]).to be == value
    end
  end

  describe ".fetch" do
    let(:result) { Metapage.fetch url }

    describe "Correct handling of https redirect on Github" do
      let(:url) { "http://github.com/colszowka/simplecov" }
      expect :title, 'colszowka/simplecov'
      expect :description, 'simplecov - Code coverage for Ruby 1.9+ with a powerful configuration library and automatic merging of coverage across test suites'
      expect :image_url, 'https://avatars0.githubusercontent.com/u/13972?v=3&s=400'
      expect :type, 'object'
      # Canonical Url has HTTPS protocol
      expect :canonical_url, 'https://github.com/colszowka/simplecov'
      expect :site_name, 'GitHub'
      expect :id, Digest::SHA1.hexdigest('https://github.com/colszowka/simplecov')
      expect :media_type, 'text'
      expect :content_type, 'text/html'
    end

    describe "Twitter Tweet with mistakenly included URL params" do
      let(:url) { "https://twitter.com/AndrewBloch/status/288393587425701888?foobar=baz" }
      expect :title, 'Andrew Bloch on Twitter'
      expect :description, "“A master class in customer service from Lego. Boy writes to Lego after losing a mini-figure. Here's their reply...”"
      expect :image_url, 'https://pbs.twimg.com/media/BAAuXaQCIAAc3dl.jpg:large'
      expect :type, 'article'
      # Canonical url does not include extra params
      expect :canonical_url, 'https://twitter.com/AndrewBloch/status/288393587425701888'
      expect :site_name, 'Twitter'
      expect :id, Digest::SHA1.hexdigest('https://twitter.com/AndrewBloch/status/288393587425701888')
      expect :media_type, 'text'
      expect :content_type, 'text/html'
    end

    describe "Website without og tags" do
      let(:url) { "http://hamburg.onruby.de?foo=bar" }

      expect :title, 'Hamburg on Ruby - Heimathafen der Hamburger Ruby Community'
      expect :description, "Hamburg on Ruby - Heimathafen der Hamburger Ruby Community - Ruby / Rails Usergroup Hamburg"
      expect :image_url, 'http://hamburg.onruby.de/assets/labels/hamburg-b325f23b118cc5761a68b6779d7990f2.ico'
      expect :type, 'website'
      # Canonical url is canonical link rel url
      expect :canonical_url, 'http://hamburg.onruby.de/'
      # Site name is the domain
      expect :site_name, 'hamburg.onruby.de'
      expect :media_type, 'text'
      expect :content_type, 'text/html'
    end

    describe "Image URL" do
      let(:url) { "https://s-media-cache-ak0.pinimg.com/736x/e3/ce/b3/e3ceb3fe3224e104ad0f019117b8e1f0.jpg" }
      expect :title, nil
      expect :description, nil
      expect :type, 'image'
      expect :canonical_url, 'https://s-media-cache-ak0.pinimg.com/736x/e3/ce/b3/e3ceb3fe3224e104ad0f019117b8e1f0.jpg'
      expect :content_type, 'image/jpeg'
      expect :site_name, nil
    end

    describe "Passing nil" do
      let(:url) { nil }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    describe "Passing ftp url" do
      let(:url) { 'ftp://de.releases.ubuntu.com/releases/10.04.4/HEADER.html' }

      it "returns nil" do
        expect(result).to be_nil
      end      
    end

    describe "Passing json url" do
      let(:url) { 'https://api.github.com/repos/rails/rails' }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    describe "Invalid URL" do
      let(:url) { 'http://fooooooooonoexist.com' }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    describe "Local URL" do
      let(:url) { 'http://localhost:3000' }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    describe "Non-success response" do
      let(:url) { 'http://httpbin.org/status/418' }

      it "returns nil" do
        expect(result).to be_nil
      end
    end
  end

  describe ".fetch!" do
    it "bubbles exception for unknown domain" do
      expect { Metapage.fetch! 'http://fooooooooonoexist.com' }.to raise_error(Metapage::ResolveError)
    end

    it "bubbles exception for network error" do
      expect_any_instance_of(HTTPClient).to receive(:get).and_raise(SocketError)
      expect { Metapage.fetch! 'http://zeit.de' }.to raise_error(Metapage::HTTPResponseError)
    end

    it "bubbles exception for local domain" do
      expect { Metapage.fetch! 'http://lvh.me' }.to raise_error(Metapage::ResolveError)
    end
  end

  describe ".extract" do
    it "returns an array of resolved metadata for urls in given text and removes invalid urls" do
      result = Metapage.extract('The text is http://github.com/colszowka/simplecov and links to http://hamburg.onruby.de?foo=bar but also to invalid http://fooooooooonoexist.com')
      expect(result.map(&:title)).to be == ['colszowka/simplecov', 'Hamburg on Ruby - Heimathafen der Hamburger Ruby Community']
    end

    it "correctly handles www. urls without protocol prefix" do
      result = Metapage.extract("www.github.com/colszowka/simplecov\nwww.xkcd.com/about/")
      expect(result.map(&:title)).to be == ['colszowka/simplecov', 'xkcd - A webcomic']
    end

    it "correctly handles newlines as separators between urls" do
      result = Metapage.extract("http://github.com/colszowka/simplecov\nhttp://hamburg.onruby.de?foo=bar")
      expect(result.map(&:title)).to be == ['colszowka/simplecov', 'Hamburg on Ruby - Heimathafen der Hamburger Ruby Community']
    end

    it "correctly handles periods at the end of a sentence" do
      result = Metapage.extract("This is a sentence linking to http://github.com/colszowka/simplecov.")
      expect(result.map(&:title)).to be == ['colszowka/simplecov']
    end

    it "correctly handles multiple periods at the end of a sentence" do
      result = Metapage.extract("This is a sentence linking to http://github.com/colszowka/simplecov...")
      expect(result.map(&:title)).to be == ['colszowka/simplecov']
    end

    it "correctly handles periods at the beginning of a url" do
      result = Metapage.extract("This is a sentence .http://github.com/colszowka/simplecov is the url")
      expect(result.map(&:title)).to be == ['colszowka/simplecov']
    end
    
    it "correctly handles commas in a sentence" do
      result = Metapage.extract("This is a sentence linking to http://github.com/colszowka/simplecov, but it also has a comma.")
      expect(result.map(&:title)).to be == ['colszowka/simplecov']
    end
  end

  describe ".extract!" do
    it "bubbles exceptions for invalid urls" do
      expect { Metapage.extract! 'The invalid url is http://fooooooooonoexist.com' }.to raise_error(Metapage::ResolveError)
    end
  end
end
