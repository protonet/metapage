# Metapage

A tiny class for extracting title, description and some further information from given urls using [open graph](http://www.ogp.me) and regular meta tags.

**Why?** For example this can be used for enriching urls submitted in a chat application.

## Features
  
  * Fetch open graph info for a page, with fallback to regular meta tags to give *something* for most HTML urls
  * Bulk-fetch info for any urls contained in a given text snippet
  * Checks if the given URL's host resolves via [Google DNS](https://developers.google.com/speed/public-dns/) and
    is not on a [private netowrk](https://en.wikipedia.org/wiki/Private_network) subnet to slow down clever people
    from entering private urls like `http://localhost:3000/secret` to explore your network.

## Installing

Add `gem 'metapage'` to your `Gemfile` or `gem install metapage` on your command line.

## Usage

Fetch a specific URL. Returns `nil` if the content is not html or loading fails due to invalid url, http response or timeout.

    Metapage.fetch('https://github.com/colszowka/simplecov').to_h
    {:title=>"colszowka/simplecov",
     :description=>"simplecov - Code coverage for Ruby 1.9+ with a powerful configuration library and automatic merging of coverage across test suites",
     :image_url=>"https://avatars0.githubusercontent.com/u/13972?v=3&s=400",
     :type=>"object",
     :canonical_url=>"https://github.com/colszowka/simplecov",
     :site_name=>"GitHub"}

Extract urls from a given string and fetch the metadata for them. Only returns successfully retrieved results.

    msg = "The text is http://github.com/colszowka/simplecov and links to http://hamburg.onruby.de?foo=bar but also to invalid http://fooooooooonoexist.com"
    Metapage.extract(msg).map(&:title)
    #=> ['colszowka/simplecov', 'Hamburg on Ruby - Heimathafen der Hamburger Ruby Community']

Both `Metapage.fetch` and `Metapage.extract` have equivalent bang methods `fetch!` and `extract!` that will bubble HTTP or parsing exceptions instead of returning
nil or silently ignoring invalid urls.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/colszowka/metapage/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
