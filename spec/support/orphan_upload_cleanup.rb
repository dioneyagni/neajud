# frozen_string_literal: true

require "fileutils"
require "sqlite3"

# Reads Arquivo uuids straight from the development sqlite3 file, bypassing
# ActiveRecord entirely. Using AR's establish_connection here would register a
# second pool that rspec-rails' transactional-fixtures machinery auto-pins for
# rollback, corrupting the *test* example's own teardown.
#
#   DevelopmentArquivoUuids.new(db_path: "storage/development.sqlite3").call
#   # => ["3f2a-...", ...]
class DevelopmentArquivoUuids
  def initialize(db_path:)
    @db_path = db_path
  end

  def call
    raise ArgumentError, "development db_path missing (got nil, expected a file path)" if @db_path.nil?

    db = SQLite3::Database.new(@db_path.to_s, readonly: true)
    db.execute("SELECT uuid FROM arquivos").flatten
  ensure
    db&.close
  end
end

# Removes storage/stamps/:uuid folders that request specs leave behind: DB rows
# roll back but the uploaded folders persist, and bin/check-residues flags them.
#
# Fail-safe: a folder is deleted only when EVERY uuid source was read. If any
# source raises (e.g. development DB missing), nothing is deleted — otherwise an
# unreadable dev DB would look like "no known uuids" and wipe real dev uploads.
#
#   OrphanUploadCleanup.new(stamps_dir: dir, uuid_sources: [-> { %w[a b] }]).call
class OrphanUploadCleanup
  def initialize(stamps_dir:, uuid_sources:, warn_io: $stderr)
    @stamps_dir = stamps_dir
    @uuid_sources = uuid_sources
    @warn_io = warn_io
  end

  # Returns the removed directories ([] when skipped).
  def call
    orphans = orphan_dirs(known_uuids)
    orphans.each { |dir| FileUtils.rm_rf(dir) }
    orphans
  rescue StandardError => e
    @warn_io.puts("OrphanUploadCleanup skipped, deleted nothing (#{@stamps_dir}): #{e.class}: #{e.message}")
    []
  end

  private

  def known_uuids
    @uuid_sources.flat_map(&:call).uniq
  end

  def orphan_dirs(known)
    Dir.glob(File.join(@stamps_dir.to_s, "*")).reject { |dir| known.include?(File.basename(dir)) }
  end
end
