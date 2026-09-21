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

  def test_apply_threshold_row_rewrites_an_edited_meaning_cell
    edited = File.read("README.md").sub(
      "| `--threshold FLOAT` | Exit 1 when",
      "| `--threshold FLOAT` | garbled when"
    )
    refute_includes edited, DocsContract.contract.fetch("threshold_readme")
    restored = DocsContract.send(:apply_threshold_row, edited)
    assert_includes restored, "| `--threshold FLOAT` | #{DocsContract.contract.fetch('threshold_readme')} |"
  end

  def test_apply_action_rewrites_edited_descriptions_by_yaml_key
    edited = File.read("action.yml")
      .sub("Fail (exit 1)", "Fails with exit 1")
      .sub("The exit code returned by mutineer", "Exit status from mutineer")
    refute_includes edited, DocsContract.contract.fetch("threshold_action")
    restored = DocsContract.send(:apply_action, edited)
    assert_includes restored, DocsContract.contract.fetch("threshold_action")
    assert_includes restored, DocsContract.contract.fetch("exit_code_action")
  end

  def test_apply_threshold_row_raises_when_the_flag_row_is_missing
    error = assert_raises(RuntimeError) { DocsContract.send(:apply_threshold_row, "| `--jobs N` | Parallel |\n") }
    assert_match(/target missing/, error.message)
  end

  def test_apply_action_raises_when_the_yaml_keys_are_missing
    error = assert_raises(RuntimeError) { DocsContract.send(:apply_action, "name: Mutineer\n") }
    assert_match(/target missing/, error.message)
  end

  def test_json_schema_html_carries_markdown_source_content
    md = File.read("docs/json-schema.md")
    html = File.read("docs/json-schema.html")
    assert_includes html, 'id="exit-codes"'
    assert_includes html, 'aria-label="Exit codes"'
    assert_includes html, "schema_version"
    assert_includes plain(html), plain(DocsContract.meaning_plain("0"))
    md.scan(/^\#{2,3}\s+(.+)$/).flatten.each do |title|
      id = DocsContract::HEADING_IDS[title]
      assert id, "json-schema.md heading #{title.inspect} needs a HEADING_IDS entry"
      assert_includes html, %(id="#{id}")
    end
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
