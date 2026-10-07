require "rails_helper"
require_relative "../support/fake_uploads"

RSpec.describe ArquivoUploadService do
  let(:fixtures) { Rails.root.join("spec/fixtures/files") }
  let(:tmp) { Rails.root.join("tmp") }

  def upload(path, type = "image/tiff")
    Rack::Test::UploadedFile.new(path, type)
  end

  # A real PNG saved with a .tif name: extension and format disagree.
  def png_named_tif
    path = tmp.join("upload-spec-fake.tif").to_s
    system("convert", "-size", "10x10", "xc:red", "PNG:#{path}", exception: true)
    path
  end

  after { FileUtils.rm_f(Dir[tmp.join("upload-spec-*")]) }

  it "saves the arquivo from the file, stores version 1 and processes it" do
    arquivo = described_class.call(upload(fixtures.join("02-no_spot.tif")), remote_ip: "1.2.3.4")
    version = arquivo.approved_version
    expect([ arquivo.persisted?, arquivo.filename, arquivo.extension, arquivo.category ]).to eq([ true, "02-no_spot", "tif", "artes" ])
    expect([ version.version_number, version.approved, File.exist?(version.original_path) ]).to eq([ 1, true, true ])
    expect(version.reload.preview_file).to be_present
  ensure
    FileUtils.rm_rf(File.join(ArquivoVersion::STORAGE_BASE, arquivo.uuid)) if arquivo&.persisted?
  end

  # Etapa 1.2 (3/3, parte 3c): "…-ESQ" in the name is the side; one already
  # set (the upload's conference) wins.
  it "reads the side from the file name unless it was set" do
    caminho = tmp.join("upload-spec-20-BLUEY-LATERAL-29_30-ESQ.tif").to_s
    FileUtils.cp(fixtures.join("02-no_spot.tif"), caminho)
    lido = described_class.call(upload(caminho), remote_ip: "1.2.3.4")
    escolhido = described_class.call(upload(caminho), remote_ip: "1.2.3.4", arquivo: Arquivo.new(lado: "direito"))
    expect([ lido.lado, escolhido.lado ]).to eq(%w[esquerdo direito])
  ensure
    [ lido, escolhido ].compact.select(&:persisted?).each { |a| FileUtils.rm_rf(File.join(ArquivoVersion::STORAGE_BASE, a.uuid)) }
  end

  it "keeps attributes set on the arquivo it is given" do
    client = create(:client)
    arquivo = described_class.call(upload(fixtures.join("02-no_spot.tif")), remote_ip: "1.2.3.4", arquivo: Arquivo.new(client: client))
    expect(arquivo.client).to eq(client)
  ensure
    FileUtils.rm_rf(File.join(ArquivoVersion::STORAGE_BASE, arquivo.uuid)) if arquivo&.persisted?
  end

  it "rejects a file whose real format doesn't match its extension, saving nothing" do
    arquivo = described_class.call(upload(png_named_tif), remote_ip: "1.2.3.4")
    expect(arquivo).not_to be_persisted
    expect(arquivo.errors[:extension]).to eq([ "declared 'TIF' but file is 'PNG'" ])
    expect(ArquivoVersion.count).to eq(0)
  end

  it "rejects a file whose format can't be identified" do
    path = tmp.join("upload-spec-text.tif").to_s
    File.write(path, "not an image")
    arquivo = described_class.call(upload(path), remote_ip: "1.2.3.4")
    expect(arquivo.errors[:original_file]).to eq([ "unable to identify file format" ])
  end

  it "rejects files over 1GB and reports the uploader's IP for abuse detection" do
    # The test env runs jobs inline; the enqueue matcher needs the :test adapter.
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    big = OversizeUpload.new(upload(fixtures.join("02-no_spot.tif")), size: 2.gigabytes)
    arquivo = nil
    expect { arquivo = described_class.call(big, remote_ip: "9.9.9.9") }
      .to have_enqueued_job(AbuseDetectionJob).with(ip_address: "9.9.9.9", file_size: 2.gigabytes)
    expect([ arquivo.persisted?, arquivo.errors[:original_file] ]).to eq([ false, [ "exceeds maximum size of 1GB" ] ])
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  describe ".erro_de_tipo" do
    it "is nil for a matching file and for extensions that can't be verified" do
      tif = upload(fixtures.join("02-no_spot.tif"))
      expect(described_class.erro_de_tipo("tif", tif)).to be_nil
      unverifiable = FileValidator::UNVERIFIABLE_EXTENSIONS.first
      expect(described_class.erro_de_tipo(unverifiable, upload(png_named_tif))).to be_nil
    end
  end
end
