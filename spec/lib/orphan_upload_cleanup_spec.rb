require "rails_helper"
require "tmpdir"
require "stringio"
require "sqlite3"

# Named fakes instead of inline stubs (AGENTS.md: mock external I/O with fake classes).
class FakeUuidSource
  def initialize(uuids)
    @uuids = uuids
  end

  def call
    @uuids
  end
end

class UnreadableUuidSource
  def call
    raise SQLite3::CantOpenException, "unable to open database file"
  end
end

RSpec.describe OrphanUploadCleanup do
  let(:stamps_dir) { Dir.mktmpdir("stamps") }
  let(:warnings) { StringIO.new }

  after { FileUtils.rm_rf(stamps_dir) }

  def make_folder(uuid)
    FileUtils.mkdir_p(File.join(stamps_dir, uuid, "original"))
  end

  def cleanup(*sources)
    described_class.new(stamps_dir: stamps_dir, uuid_sources: sources, warn_io: warnings)
  end

  it "removes folders no source knows and keeps the known ones" do
    make_folder("known-in-test")
    make_folder("known-in-dev")
    make_folder("orphan")

    removed = cleanup(FakeUuidSource.new(%w[known-in-test]), FakeUuidSource.new(%w[known-in-dev])).call

    expect(removed.map { |d| File.basename(d) }).to eq(%w[orphan])
    expect(Dir.children(stamps_dir)).to contain_exactly("known-in-test", "known-in-dev")
  end

  # Regression: an unreadable development DB used to rescue to [] and every dev
  # upload looked like an orphan, so the suite wiped real uploads.
  it "deletes nothing and warns when a uuid source cannot be read" do
    make_folder("real-dev-upload")

    removed = cleanup(FakeUuidSource.new([]), UnreadableUuidSource.new).call

    expect(removed).to eq([])
    expect(Dir.children(stamps_dir)).to eq(%w[real-dev-upload])
    expect(warnings.string).to include("deleted nothing", "CantOpenException", "unable to open database file")
  end

  it "does nothing when the stamps directory is missing" do
    FileUtils.rm_rf(stamps_dir)

    expect(cleanup(FakeUuidSource.new([])).call).to eq([])
    expect(warnings.string).to be_empty
  end
end

RSpec.describe DevelopmentArquivoUuids do
  let(:db_dir) { Dir.mktmpdir("devdb") }
  let(:db_path) { File.join(db_dir, "development.sqlite3") }

  after { FileUtils.rm_rf(db_dir) }

  def seed_arquivos(*uuids)
    db = SQLite3::Database.new(db_path)
    db.execute("CREATE TABLE arquivos (id INTEGER PRIMARY KEY, uuid TEXT)")
    uuids.each { |uuid| db.execute("INSERT INTO arquivos (uuid) VALUES (?)", [ uuid ]) }
    db.close
  end

  it "reads uuids from the development sqlite3 file directly" do
    seed_arquivos("dev-1", "dev-2")

    expect(described_class.new(db_path: db_path).call).to contain_exactly("dev-1", "dev-2")
  end

  it "raises when the development DB file does not exist" do
    expect { described_class.new(db_path: db_path).call }.to raise_error(SQLite3::CantOpenException)
  end

  it "raises when the table does not exist yet (unmigrated dev DB)" do
    SQLite3::Database.new(db_path).close
    expect { described_class.new(db_path: db_path).call }.to raise_error(SQLite3::SQLException, /no such table/)
  end

  it "raises naming the expected shape when db_path is nil" do
    expect { described_class.new(db_path: nil).call }.to raise_error(ArgumentError, /got nil, expected a file path/)
  end
end
