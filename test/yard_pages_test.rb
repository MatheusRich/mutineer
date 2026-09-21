# frozen_string_literal: true

require_relative "test_helper"
require_relative "../rake/site_docs"
require_relative "../rake/yard_pages"
require_relative "../lib/mutineer/version"

# #92: published YARD HTML tracks the shipped gem.
class YardPagesTest < Minitest::Test
  def test_catalog_lists_the_api_root
    paths = MutineerSiteDocs::CATALOG.map(&:path)
    assert_includes paths, "/api/"
  end

  def test_api_index_exists_and_names_this_version
    assert_includes File.read("docs/api/index.html"), "Mutineer"
    listed = File.read("docs/api/_index.html") + File.read("docs/api/Mutineer.html")
    assert_includes listed, Mutineer::VERSION
  end

  def test_site_nav_links_to_api
    %w[docs/index.html docs/agentic-coding.html docs/json-schema.html docs/sample-report.html].each do |path|
      assert_includes File.read(path), 'href="api/"', "#{path} should link to api/"
    end
  end

  def test_documentation_uri_stays_the_pages_root
    spec = File.read("mutineer.gemspec")
    assert_includes spec, '"documentation_uri" => "https://davidteren.github.io/mutineer/"'
  end

  def test_committed_api_docs_match_a_fresh_yard_build
    assert YardPages.current?, "docs/api is stale — run `rake yard:pages`"
  end
end
