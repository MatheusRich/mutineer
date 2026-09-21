# frozen_string_literal: true

require_relative "test_helper"
require_relative "../rake/docs_contract"
require_relative "../rake/site_docs"

# #82: one contract file, generated copies, CI fails when they drift.
class DocsContractTest < Minitest::Test
  SURFACES = %w[
    README.md
    docs/json-schema.md
    docs/json-schema.html
    docs/llms-full.txt
    docs/agentic-coding.md
  ].freeze

  def test_every_contract_surface_carries_the_same_exit_codes
    SURFACES.each do |path|
      text = File.read(path)
      %w[0 1 2].each do |code|
        assert_includes text, code
        assert_includes plain(text), plain(DocsContract.meaning_plain(code)),
          "#{path} is missing exit-code #{code} meaning"
      end
    end
  end

  def test_llms_full_matches_a_fresh_concat_of_the_markdown_sources
    assert_equal "#{DocsContract.llms_full_txt.rstrip}\n", File.read("docs/llms-full.txt")
  end

  def test_json_schema_html_matches_a_fresh_render_of_the_markdown
    assert_equal DocsContract.json_schema_html, File.read("docs/json-schema.html")
  end

  def test_json_schema_html_keeps_playwright_summary_region_and_markdown_alternate
    html = File.read("docs/json-schema.html")
    assert_includes html, 'aria-label="Summary fields"'
    assert_includes html, 'rel="alternate" type="text/markdown"'
    assert_includes html, "https://davidteren.github.io/mutineer/json-schema.md"
  end

  def test_action_yml_descriptions_come_from_the_contract_file
    yaml = File.read("action.yml")
    assert_includes yaml, DocsContract.contract.fetch("threshold_action")
    assert_includes yaml, DocsContract.contract.fetch("exit_code_action")
  end

  def test_docs_check_is_clean
    assert_empty MutineerSiteDocs.stale_files
  end

  private

  # Strip markup so HTML and Markdown meanings compare.
  #
  # @param text [String]
  # @return [String]
  def plain(text)
    text.gsub(/<[^>]+>/, "").gsub(/[`*]/, "").gsub(/\s+/, " ").gsub(/ +([,.;:])/, '\1').strip
  end
end
