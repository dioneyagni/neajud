require "rails_helper"
require "open3"

RSpec.describe StampProcessingJob do
  let(:stamp) { create(:stamp) }
  let!(:version) { create(:stamp_version, stamp: stamp, version_number: 1, approved: true) }
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

  def version_storage_dir(v)
    File.join(Rails.root, "storage", "stamps", v.stamp.uuid, "v#{v.version_number}")
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
      expect(version.reload.has_spots).to be true
    end

    it "detects spots in CMYK spot file" do
      copy_to_version(version, "01.tif")
      version.update!(category: "artes")
      job.send(:detect_spots, version)
      expect(version.reload.has_spots).to be true
    end

    it "does not detect spots in no-spot files" do
      copy_to_version(version, "02-no_spot.tif")
      version.update!(category: "artes")
      job.send(:detect_spots, version)
      expect(version.reload.has_spots).to be false
    end

    it "skips detection for corte category (spot_detection: false)" do
      version.update!(extension: "svg", category: "corte")
      job.send(:detect_spots, version)
      expect(version.reload.has_spots).to be false
    end

    it "runs spot detection on PSD files" do
      copy_to_version(version, "02-no_spot.psd")
      version.update!(original_file: "test.psd", extension: "psd", category: "artes")
      job.send(:detect_spots, version)
      expect(version.reload.has_spots).to be false
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
      version.reload
      expect(version.icc_profile).to eq("Adobe RGB (1998)")
    end

    it "extracts pixel dimensions" do
      job.send(:extract_metadata, version)
      version.reload
      expect(version.width_px).to eq(609)
      expect(version.height_px).to eq(486)
    end

    it "extracts DPI" do
      job.send(:extract_metadata, version)
      version.reload
      expect(version.dpi).to eq(300.0)
    end

    it "extracts metadata JSON (compression, depth, channels, file_size)" do
      job.send(:extract_metadata, version)
      version.reload
      expect(version.metadata["compression"]).to eq("LZW")
      expect(version.metadata["depth"]).to eq(8)
      expect(version.metadata["channels"]).to eq("srgb")
      expect(version.metadata["file_size"]).to be > 0
    end
  end

  describe "routing in #process_image" do
    before do
      copy_to_version(version, "02-no_spot.tif")
    end

    after do
      FileUtils.rm_rf(version_storage_dir(version))
    end

    it "routes RGB no-spot to generate_preview_rgb" do
      version.update!(has_spots: false, colorspace: "sRGB")
      expect(job).to receive(:generate_preview_rgb).and_call_original
      job.send(:process_image, version)
    end

    it "routes CMYK no-spot to generate_preview_cmyk" do
      version.update!(has_spots: false, colorspace: "CMYK")
      expect(job).to receive(:generate_preview_cmyk).and_call_original
      job.send(:process_image, version)
    end

    it "routes TIFF files with spots to generate_preview_utif regardless of colorspace" do
      version.update!(has_spots: true, colorspace: "CMYK", extension: "tif")
      expect(job).to receive(:generate_preview_utif).and_call_original
      job.send(:process_image, version)
    end

    it "routes PSD files with spots to generate_preview_rgb (not utif)" do
      version.update!(has_spots: true, colorspace: "sRGB", extension: "psd")
      expect(job).not_to receive(:generate_preview_utif)
      expect(job).to receive(:generate_preview_rgb).and_call_original
      job.send(:process_image, version)
    end

    it "routes PSD CMYK no-spot to generate_preview_cmyk" do
      version.update!(has_spots: false, colorspace: "CMYK", extension: "psd")
      expect(job).to receive(:generate_preview_cmyk).and_call_original
      job.send(:process_image, version)
    end

    it "routes EPS RGB no-spot to generate_preview_rgb" do
      version.update!(has_spots: false, colorspace: "sRGB", extension: "eps")
      expect(job).to receive(:generate_preview_rgb).and_call_original
      job.send(:process_image, version)
    end

    it "routes EPS CMYK no-spot to generate_preview_cmyk" do
      version.update!(has_spots: false, colorspace: "CMYK", extension: "eps")
      expect(job).to receive(:generate_preview_cmyk).and_call_original
      job.send(:process_image, version)
    end
  end

  describe "#perform" do
    let(:real_stamp) { create(:stamp, original_file: "test.tif", extension: "tif", colorspace: "sRGB") }
    let!(:real_version) { create(:stamp_version, stamp: real_stamp, version_number: 1, approved: true) }

    before do
      copy_to_version(real_version, "02-no_spot.tif")
    end

    after do
      FileUtils.rm_rf(version_storage_dir(real_version))
      real_stamp.destroy!
    end

    it "processes a TIFF stamp end-to-end" do
      described_class.perform_now(real_version.id)
      real_version.reload
      expect(real_version.status).to eq("processed")
      expect(real_version.preview_file).not_to be_nil
      expect(File.exist?(real_version.preview_file)).to be true
      dims = png_dimensions(real_version.preview_file)
      expect(dims).to eq([ 609, 486 ])
      expect(real_version.icc_profile).to eq("Adobe RGB (1998)")
      expect(real_version.width_px).to eq(609)
      expect(real_version.height_px).to eq(486)
      expect(real_version.dpi).to eq(300.0)
      expect(real_version.metadata["compression"]).to eq("LZW")
      expect(real_version.metadata["file_size"]).to be > 0
    end

    it "processes a PSD stamp end-to-end" do
      psd_stamp = create(:stamp, original_file: "test.psd", extension: "psd", colorspace: "sRGB")
      psd_version = create(:stamp_version, stamp: psd_stamp, version_number: 1, approved: true)

      copy_to_version(psd_version, "02-no_spot.psd")

      described_class.perform_now(psd_version.id)
      psd_version.reload
      expect(psd_version.status).to eq("processed")
      expect(psd_version.preview_file).not_to be_nil
      expect(File.exist?(psd_version.preview_file)).to be true
      dims = png_dimensions(psd_version.preview_file)
      expect(dims).to eq([ 609, 486 ])
      expect(psd_version.icc_profile).to eq("Adobe RGB (1998)")

      FileUtils.rm_rf(version_storage_dir(psd_version))
      psd_stamp.destroy!
    end

    it "processes an EPS RGB stamp end-to-end" do
      eps_stamp = create(:stamp, original_file: "eps-rgb.eps", extension: "eps", colorspace: "sRGB", category: "artes")
      eps_version = create(:stamp_version, stamp: eps_stamp, version_number: 1, approved: true)

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
      eps_stamp.destroy!
    end

    it "processes a Corte file (SVG) without generating preview" do
      svg_stamp = create(:stamp, original_file: "test.svg", extension: "svg", colorspace: "sRGB", category: "corte")
      svg_version = create(:stamp_version, stamp: svg_stamp, version_number: 1, approved: true)

      copy_to_version(svg_version, "test.svg")

      described_class.perform_now(svg_version.id)
      svg_version.reload
      expect(svg_version.status).to eq("processed")
      expect(svg_version.preview_file).to be_nil
      expect(svg_version.width_px).to eq(200)
      expect(svg_version.height_px).to eq(100)

      FileUtils.rm_rf(version_storage_dir(svg_version))
      svg_stamp.destroy!
    end
  end
end
