require "rails_helper"
require "open3"

RSpec.describe ArquivoProcessingJob do
  let(:arquivo) { create(:arquivo) }
  let!(:version) { create(:arquivo_version, arquivo: arquivo, version_number: 1, approved: true) }
  let(:job) { described_class.new }
  let(:original_path) { Rails.root.join("spec", "fixtures", "files") }

  def png_dimensions(path)
    return nil unless File.exist?(path)
    result = `identify -format '%w %h' #{Shellwords.escape(path)} 2>/dev/null`.strip
    result.split.map(&:to_i)
  end

  def png_has_visible_pixels?(path)
    return false unless File.exist?(path)
    out, _err, status = Open3.capture3(
      "python3", "-c", <<~'PYTHON', path
        import struct, zlib, sys
        PNG_HEADER = b'\x89PNG\r\n\x1a\n'
        with open(sys.argv[1], 'rb') as f:
            data = f.read()
        if data[:8] != PNG_HEADER:
            sys.exit(1)
        i, w, h, idat_data = 8, 0, 0, b''
        while i < len(data):
            length = struct.unpack('>I', data[i:i+4])[0]
            ctype = data[i+4:i+8]
            if ctype == b'IHDR':
                w, h = struct.unpack('>II', data[i+8:i+16])
            elif ctype == b'IDAT':
                idat_data += data[i+8:i+8+length]
            i += 12 + length
        if not idat_data:
            sys.exit(1)
        raw = zlib.decompress(idat_data)
        stride = w * 4 + 1
        for y in range(h):
            row = raw[y*stride+1:y*stride+stride]
            for j in range(0, w*4, 4):
                if row[j+3] > 0 and (row[j] > 0 or row[j+1] > 0 or row[j+2] > 0):
                    sys.exit(0)
        sys.exit(1)
      PYTHON
    )
    status.success?
  end

  # Strict parse so a truncated or malformed SVG raises instead of passing.
  def svg_view_box(path)
    doc = Nokogiri::XML(File.read(path)) { |config| config.strict }
    raise "Expected <svg> root in #{path}, got <#{doc.root&.name}>" unless doc.root&.name == "svg"
    doc.root["viewBox"].split.map(&:to_f)
  end

  # Rasterize so "visible content" means drawn pixels, not just <path> tags.
  def rasterize_svg(svg_path, png_path)
    system("convert", "-background", "none", "-density", "150", svg_path,
           "-define", "png:color-type=6", png_path, err: File::NULL)
  end

  # DXF strokes are often pure black (layer color 7) on a transparent
  # background, which png_has_visible_pixels? rejects (it requires RGB > 0).
  # Any opaque pixel counts as drawn content here.
  def png_max_alpha(path)
    `identify -format '%[fx:maxima.a]' #{Shellwords.escape(path)} 2>/dev/null`.to_f
  end

  def version_storage_dir(v)
    File.join(ArquivoVersion::STORAGE_BASE, v.arquivo.uuid, "v#{v.version_number}")
  end

  def copy_to_version(v, filename)
    dir = File.join(version_storage_dir(v), "original")
    FileUtils.mkdir_p(dir)
    FileUtils.cp(original_path.join(filename), File.join(dir, filename))
    v.update!(original_file: filename)
  end

  describe "#generate_preview_rgb" do
    shared_examples "RGB preview" do |label, input_file|
      context "with #{label}" do
        let(:input) { original_path.join(input_file).to_s }
        let(:output) { Rails.root.join("tmp", "test-rgb-#{label.parameterize}.png").to_s }

        after { File.delete(output) if File.exist?(output) }

        it "produces a valid PNG" do
          job.send(:generate_preview_rgb, input, output)
          expect(File.exist?(output)).to be true
          dims = png_dimensions(output)
          expect(dims).to eq([ 609, 486 ])
        end

        it "produces a PNG with visible pixels" do
          job.send(:generate_preview_rgb, input, output)
          expect(png_has_visible_pixels?(output)).to be true
        end
      end
    end

    include_examples "RGB preview", "TIFF RGB no-spot", "02-no_spot.tif"
    include_examples "RGB preview", "PSD RGB no-spot", "02-no_spot.psd"
    include_examples "RGB preview", "EPS RGB no-spot", "eps-rgb.eps"
  end

  describe "#generate_preview_cmyk" do
    shared_examples "CMYK preview" do |label, input_file|
      context "with #{label}" do
        let(:input) { original_path.join(input_file).to_s }
        let(:output) { Rails.root.join("tmp", "test-cmyk-#{label.parameterize}.png").to_s }

        after { File.delete(output) if File.exist?(output) }

        it "produces a valid PNG" do
          job.send(:generate_preview_cmyk, input, output)
          expect(File.exist?(output)).to be true
          dims = png_dimensions(output)
          expect(dims).to eq([ 609, 486 ])
        end

        it "produces a PNG with visible pixels" do
          job.send(:generate_preview_cmyk, input, output)
          expect(png_has_visible_pixels?(output)).to be true
        end

        it "converts to sRGB colorspace" do
          job.send(:generate_preview_cmyk, input, output)
          cs = `identify -format '%[colorspace]' #{Shellwords.escape(output)} 2>/dev/null`.strip
          expect(cs).to eq("sRGB")
        end
      end
    end

    include_examples "CMYK preview", "TIFF CMYK no-spot", "01-no_spot.tif"
    include_examples "CMYK preview", "PSD CMYK no-spot", "01-no_spot.psd"
    include_examples "CMYK preview", "EPS CMYK no-spot", "eps-cmyk.eps"
  end

  describe "#generate_preview_utif" do
    shared_examples "UTIF preview" do |label, filename, expected_w, expected_h|
      context "with #{label}" do
        let(:input) { original_path.join(filename).to_s }
        let(:output) { Rails.root.join("tmp", "test-utif-#{label.parameterize}.png").to_s }

        after { File.delete(output) if File.exist?(output) }

        it "produces a valid PNG" do
          job.send(:generate_preview_utif, input, output)
          expect(File.exist?(output)).to be true
          dims = png_dimensions(output)
          expect(dims).to eq([ expected_w, expected_h ])
        end

        it "produces a PNG with visible pixels" do
          job.send(:generate_preview_utif, input, output)
          expect(png_has_visible_pixels?(output)).to be true
        end
      end
    end

    include_examples "UTIF preview", "RGB spot", "02.tif", 609, 486

    context "with CMYK spot" do
      let(:input) { original_path.join("01.tif").to_s }
      let(:output) { Rails.root.join("tmp", "test-utif-cmyk-spot.png").to_s }

      after { File.delete(output) if File.exist?(output) }

      it "produces a valid PNG" do
        job.send(:generate_preview_utif, input, output)
        expect(File.exist?(output)).to be true
        dims = png_dimensions(output)
        expect(dims).to eq([ 609, 486 ])
      end

      it "produces a non-empty file" do
        job.send(:generate_preview_utif, input, output)
        expect(File.size(output)).to be > 1000
      end
    end
  end

  describe "#detect_spots" do
    after do
      FileUtils.rm_rf(version_storage_dir(version))
    end

    it "detects spots in RGB spot file" do
      copy_to_version(version, "02.tif")
      version.update!(category: "artes")
      job.send(:detect_spots, version)
      expect(version.reload.image_metadata.has_spots).to be true
    end

    it "detects spots in CMYK spot file" do
      copy_to_version(version, "01.tif")
      version.update!(category: "artes")
      job.send(:detect_spots, version)
      expect(version.reload.image_metadata.has_spots).to be true
    end

    it "does not detect spots in no-spot files" do
      copy_to_version(version, "02-no_spot.tif")
      version.update!(category: "artes")
      job.send(:detect_spots, version)
      expect(version.reload.image_metadata.has_spots).to be false
    end

    it "skips detection for corte category (no image_metadata created)" do
      version.update!(extension: "svg", category: "corte")
      job.send(:detect_spots, version)
      expect(version.reload.image_metadata).to be_nil
    end

    it "runs spot detection on PSD files" do
      copy_to_version(version, "02-no_spot.psd")
      version.update!(extension: "psd", category: "artes")
      job.send(:detect_spots, version)
      expect(version.reload.image_metadata.has_spots).to be false
    end
  end

  describe "#extract_metadata" do
    before do
      copy_to_version(version, "02-no_spot.tif")
    end

    after do
      FileUtils.rm_rf(version_storage_dir(version))
    end

    it "extracts ICC profile name" do
      job.send(:extract_metadata, version)
      expect(version.reload.image_metadata.icc_profile).to eq("Adobe RGB (1998)")
    end

    it "extracts pixel dimensions" do
      job.send(:extract_metadata, version)
      meta = version.reload.image_metadata
      expect(meta.width_px).to eq(609)
      expect(meta.height_px).to eq(486)
    end

    it "extracts DPI" do
      job.send(:extract_metadata, version)
      expect(version.reload.image_metadata.dpi).to eq(300.0)
    end

    it "extracts metadata JSON (compression, depth, channels, file_size)" do
      job.send(:extract_metadata, version)
      meta = version.reload.image_metadata
      expect(meta.metadata["compression"]).to eq("LZW")
      expect(meta.metadata["depth"]).to eq(8)
      expect(meta.metadata["channels"]).to eq("srgb")
      expect(meta.metadata["file_size"]).to be > 0
    end
  end

  describe "#generate_preview_dxf" do
    # Expected sizes come from outside the dxf library: CABEDAL from its
    # $EXTMAX - $EXTMIN header; 29-30's header extents are unset (±1e20), so
    # its sole piece as measured by DxfOrganizationService (see e2e fixture).
    shared_examples "DXF preview" do |label, input_file, expected_w, expected_h|
      context "with #{label}" do
        let(:input) { original_path.join(input_file).to_s }
        let(:output) { Rails.root.join("tmp", "test-dxf-#{label.parameterize}.svg").to_s }
        let(:raster) { output.sub(/\.svg\z/, ".png") }

        after { [ output, raster ].each { |f| File.delete(f) if File.exist?(f) } }

        it "produces a well-formed SVG" do
          job.send(:generate_preview_dxf, input, output)
          expect { svg_view_box(output) }.not_to raise_error
        end

        it "has a viewBox matching the source drawing size" do
          job.send(:generate_preview_dxf, input, output)
          _x, _y, width, height = svg_view_box(output)
          expect(width).to be_within(expected_w * 0.005).of(expected_w)
          expect(height).to be_within(expected_h * 0.005).of(expected_h)
        end

        it "renders visible strokes when rasterized" do
          job.send(:generate_preview_dxf, input, output)
          expect(rasterize_svg(output, raster)).to be true
          expect(png_max_alpha(raster)).to be > 0
        end
      end
    end

    include_examples "DXF preview", "single piece 29-30", "29-30.dxf", 218.69, 225.48
    include_examples "DXF preview", "multi-size CABEDAL", "CABEDAL - 35 AO 43.dxf", 2294.4947, 361.2683

    it "raises when the input file does not exist" do
      output = Rails.root.join("tmp", "test-dxf-missing.svg").to_s
      expect { job.send(:generate_preview_dxf, "/nonexistent/missing.dxf", output) }
        .to raise_error(RuntimeError, "DXF preview failed")
      expect(File.exist?(output)).to be false
    end
  end

  describe "routing in #process_image" do
    before do
      copy_to_version(version, "02-no_spot.tif")
    end

    after do
      FileUtils.rm_rf(version_storage_dir(version))
    end

    it "routes DXF to generate_preview_dxf and stores an SVG preview" do
      copy_to_version(version, "29-30.dxf")
      version.update!(extension: "dxf")
      expect(job).to receive(:generate_preview_dxf).and_call_original
      job.send(:process_image, version)
      expect(version.reload.preview_file).to end_with("preview/preview.svg")
    end

    it "routes RGB no-spot to generate_preview_rgb" do
      version.create_image_metadata!(has_spots: false, colorspace: "sRGB")
      expect(job).to receive(:generate_preview_rgb).and_call_original
      job.send(:process_image, version)
    end

    it "routes CMYK no-spot to generate_preview_cmyk" do
      version.create_image_metadata!(has_spots: false, colorspace: "CMYK")
      expect(job).to receive(:generate_preview_cmyk).and_call_original
      job.send(:process_image, version)
    end

    it "routes TIFF files with spots to generate_preview_utif regardless of colorspace" do
      version.create_image_metadata!(has_spots: true, colorspace: "CMYK")
      version.update!(extension: "tif")
      expect(job).to receive(:generate_preview_utif).and_call_original
      job.send(:process_image, version)
    end

    it "routes PSD files with spots to generate_preview_rgb (not utif)" do
      version.create_image_metadata!(has_spots: true, colorspace: "sRGB")
      version.update!(extension: "psd")
      expect(job).not_to receive(:generate_preview_utif)
      expect(job).to receive(:generate_preview_rgb).and_call_original
      job.send(:process_image, version)
    end

    it "routes PSD CMYK no-spot to generate_preview_cmyk" do
      version.create_image_metadata!(has_spots: false, colorspace: "CMYK")
      version.update!(extension: "psd")
      expect(job).to receive(:generate_preview_cmyk).and_call_original
      job.send(:process_image, version)
    end

    it "routes EPS RGB no-spot to generate_preview_rgb" do
      version.create_image_metadata!(has_spots: false, colorspace: "sRGB")
      version.update!(extension: "eps")
      expect(job).to receive(:generate_preview_rgb).and_call_original
      job.send(:process_image, version)
    end

    it "routes EPS CMYK no-spot to generate_preview_cmyk" do
      version.create_image_metadata!(has_spots: false, colorspace: "CMYK")
      version.update!(extension: "eps")
      expect(job).to receive(:generate_preview_cmyk).and_call_original
      job.send(:process_image, version)
    end
  end

  describe "#perform" do
    let(:real_arquivo) { create(:arquivo, extension: "tif") }
    let!(:real_version) { create(:arquivo_version, arquivo: real_arquivo, version_number: 1, approved: true) }

    before do
      copy_to_version(real_version, "02-no_spot.tif")
    end

    after do
      FileUtils.rm_rf(version_storage_dir(real_version))
      real_arquivo.destroy!
    end

    it "processes a TIFF arquivo end-to-end" do
      described_class.perform_now(real_version.id)
      real_version.reload
      expect(real_version.status).to eq("processed")
      expect(real_version.preview_file).not_to be_nil
      expect(File.exist?(real_version.preview_file)).to be true
      dims = png_dimensions(real_version.preview_file)
      expect(dims).to eq([ 609, 486 ])
      meta = real_version.image_metadata
      expect(meta.icc_profile).to eq("Adobe RGB (1998)")
      expect(meta.width_px).to eq(609)
      expect(meta.height_px).to eq(486)
      expect(meta.dpi).to eq(300.0)
      expect(meta.metadata["compression"]).to eq("LZW")
      expect(meta.metadata["file_size"]).to be > 0
    end

    it "processes a PSD arquivo end-to-end" do
      psd_arquivo = create(:arquivo, extension: "psd")
      psd_version = create(:arquivo_version, arquivo: psd_arquivo, version_number: 1, approved: true)

      copy_to_version(psd_version, "02-no_spot.psd")

      described_class.perform_now(psd_version.id)
      psd_version.reload
      expect(psd_version.status).to eq("processed")
      expect(psd_version.preview_file).not_to be_nil
      expect(File.exist?(psd_version.preview_file)).to be true
      dims = png_dimensions(psd_version.preview_file)
      expect(dims).to eq([ 609, 486 ])
      expect(psd_version.image_metadata.icc_profile).to eq("Adobe RGB (1998)")

      FileUtils.rm_rf(version_storage_dir(psd_version))
      psd_arquivo.destroy!
    end

    it "processes an EPS RGB arquivo end-to-end" do
      eps_arquivo = create(:arquivo, extension: "eps", category: "artes")
      eps_version = create(:arquivo_version, arquivo: eps_arquivo, version_number: 1, approved: true)

      copy_to_version(eps_version, "eps-rgb.eps")

      described_class.perform_now(eps_version.id)
      eps_version.reload
      expect(eps_version.status).to eq("processed")
      expect(eps_version.preview_file).not_to be_nil
      expect(File.exist?(eps_version.preview_file)).to be true
      dims = png_dimensions(eps_version.preview_file)
      expect(dims).to eq([ 609, 486 ])
      expect(eps_version.category).to eq("artes")

      FileUtils.rm_rf(version_storage_dir(eps_version))
      eps_arquivo.destroy!
    end

    it "processes a Corte file (SVG) without generating preview" do
      svg_arquivo = create(:arquivo, extension: "svg", category: "corte")
      svg_version = create(:arquivo_version, arquivo: svg_arquivo, version_number: 1, approved: true)

      copy_to_version(svg_version, "test.svg")

      described_class.perform_now(svg_version.id)
      svg_version.reload
      expect(svg_version.status).to eq("processed")
      expect(svg_version.preview_file).to be_nil
      expect(svg_version.image_metadata.width_px).to eq(200)
      expect(svg_version.image_metadata.height_px).to eq(100)

      FileUtils.rm_rf(version_storage_dir(svg_version))
      svg_arquivo.destroy!
    end
  end

  # Etapa 0.3: processing is queued, so a modelo may be chosen before the
  # preview exists; the job retries the tamanho auto-assign at the end.
  describe "#assign_tamanho_after_processing" do
    let(:arte) { create(:arquivo, category: "artes", modelo: create(:modelo)) }
    let(:arte_version) { create(:arquivo_version, arquivo: arte).tap { |v| arte.update!(approved_version: v) } }

    it "assigns the tamanho for an arte with modelo and no tamanho" do
      expect(TamanhoAutoAssignService).to receive(:call).with(arte)
      job.send(:assign_tamanho_after_processing, arte_version)
    end

    it "skips an arte whose peça was set explicitly (Escolher/Enviar arte)" do
      arte.update!(peca: create(:peca))
      expect(TamanhoAutoAssignService).not_to receive(:call)
      job.send(:assign_tamanho_after_processing, arte_version)
    end

    it "skips artes without modelo, with a tamanho, and non-approved versions" do
      expect(TamanhoAutoAssignService).not_to receive(:call)
      sem_modelo = create(:arquivo, category: "artes")
      job.send(:assign_tamanho_after_processing, create(:arquivo_version, arquivo: sem_modelo).tap { |v| sem_modelo.update!(approved_version: v) })
      arte_version
      job.send(:assign_tamanho_after_processing, create(:arquivo_version, arquivo: arte))
    end

    it "never fails the processing when the auto-assign raises" do
      allow(TamanhoAutoAssignService).to receive(:call).and_raise("boom")
      expect { job.send(:assign_tamanho_after_processing, arte_version) }.not_to raise_error
    end
  end
end
