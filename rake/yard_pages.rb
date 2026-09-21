# frozen_string_literal: true

require "fileutils"
require "tmpdir"

# Publish YARD HTML under `docs/api/` so GitHub Pages tracks the shipped gem.
module YardPages
  # Pages output directory (the `/api/` URL on GitHub Pages).
  OUTPUT = "docs/api"

  class << self
    # Generate YARD HTML into `docs/api/` and disable Jekyll on the site.
    #
    # @return [void]
    def generate!
      FileUtils.rm_rf(OUTPUT)
      ok = system("bundle", "exec", "yard", "doc", "--output-dir", OUTPUT)
      raise "yard doc failed" unless ok

      FileUtils.touch(File.join(OUTPUT, ".nojekyll"))
      FileUtils.touch("docs/.nojekyll")
    end

    # True when committed `docs/api` matches a fresh YARD build.
    #
    # Generation timestamps and the footer Ruby patch are ignored so the
    # Linux `rake yard:pages:check` gate stays stable. Do not call this from
    # the default minitest suite — a full rebuild is slow and still
    # OS-sensitive (file list / template drift).
    #
    # @return [Boolean]
    def current?
      return false unless File.directory?(OUTPUT)

      Dir.mktmpdir("yard-pages") do |tmp|
        ok = system("bundle", "exec", "yard", "doc", "--output-dir", tmp)
        raise "yard doc failed" unless ok

        FileUtils.touch(File.join(tmp, ".nojekyll"))
        equivalent?(OUTPUT, tmp)
      end
    end

    # Compare two YARD trees after stripping the "Generated on" stamp.
    #
    # @param left [String]
    # @param right [String]
    # @return [Boolean]
    def equivalent?(left, right)
      left_files = relative_files(left)
      right_files = relative_files(right)
      return false unless left_files == right_files

      left_files.all? do |rel|
        normalize(File.read(File.join(left, rel))) == normalize(File.read(File.join(right, rel)))
      end
    end

    private

    # @param dir [String]
    # @return [Array<String>]
    def relative_files(dir)
      Dir.glob(File.join(dir, "**/*"), File::FNM_DOTMATCH).select { |p| File.file?(p) }
         .map { |p| p.delete_prefix("#{dir}/") }.sort
    end

    # @param text [String]
    # @return [String]
    def normalize(text)
      text.gsub(/Generated on .+ by/, "Generated on DATE by")
          .gsub(/\(ruby-\d+\.\d+\.\d+\)/, "(ruby-VERSION)")
    end
  end
end
