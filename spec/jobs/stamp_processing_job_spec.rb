require "rails_helper"
require "open3"

RSpec.describe StampProcessingJob do
  let(:stamp) { create(:stamp) }
  let(:job) { described_class.new }
  let(:original_path) { Rails.root.join("tmp", "files-upload") }

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

  describe "#generate_preview_rgb" do
    let(:input) { original_path.join("02-no_spot.tif").to_s }
    let(:output) { Rails.root.join("tmp", "test-rgb-output.png").to_s }

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

  describe "#generate_preview_cmyk" do
    let(:input) { original_path.join("01-no_spot.tif").to_s }
    let(:output) { Rails.root.join("tmp", "test-cmyk-output.png").to_s }

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
    before do
      FileUtils.mkdir_p(Rails.root.join("storage", "stamps", stamp.uuid, "original"))
    end

    after do
      FileUtils.rm_rf(Rails.root.join("storage", "stamps", stamp.uuid))
    end

    it "detects spots in RGB spot file" do
      FileUtils.cp(original_path.join("02.tif"),
                   Rails.root.join("storage", "stamps", stamp.uuid, "original", "02.tif"))
      stamp.update!(original_file: "02.tif")
      job.send(:detect_spots, stamp)
      expect(stamp.reload.has_spots).to be true
    end

    it "detects spots in CMYK spot file" do
      FileUtils.cp(original_path.join("01.tif"),
                   Rails.root.join("storage", "stamps", stamp.uuid, "original", "01.tif"))
      stamp.update!(original_file: "01.tif")
      job.send(:detect_spots, stamp)
      expect(stamp.reload.has_spots).to be true
    end

    it "does not detect spots in no-spot files" do
      FileUtils.cp(original_path.join("02-no_spot.tif"),
                   Rails.root.join("storage", "stamps", stamp.uuid, "original", "02-no_spot.tif"))
      stamp.update!(original_file: "02-no_spot.tif")
      job.send(:detect_spots, stamp)
      expect(stamp.reload.has_spots).to be false
    end

    it "skips detection for non-TIFF formats" do
      stamp.update!(extension: "jpg")
      job.send(:detect_spots, stamp)
      expect(stamp.reload.has_spots).to be false
    end
  end

  describe "routing in #process_image" do
    before do
      FileUtils.mkdir_p(Rails.root.join("storage", "stamps", stamp.uuid, "original"))
      FileUtils.cp(original_path.join("02-no_spot.tif"),
                   Rails.root.join("storage", "stamps", stamp.uuid, "original", "test.tif"))
      stamp.update!(original_file: "test.tif")
    end

    after do
      FileUtils.rm_rf(Rails.root.join("storage", "stamps", stamp.uuid))
    end

    it "routes RGB no-spot to generate_preview_rgb" do
      stamp.update!(has_spots: false, colorspace: "sRGB")
      expect(job).to receive(:generate_preview_rgb).and_call_original
      job.send(:process_image, stamp)
    end

    it "routes CMYK no-spot to generate_preview_cmyk" do
      stamp.update!(has_spots: false, colorspace: "CMYK")
      expect(job).to receive(:generate_preview_cmyk).and_call_original
      job.send(:process_image, stamp)
    end

    it "routes files with spots to generate_preview_utif regardless of colorspace" do
      stamp.update!(has_spots: true, colorspace: "CMYK")
      expect(job).to receive(:generate_preview_utif).and_call_original
      job.send(:process_image, stamp)
    end
  end

  describe "#perform" do
    let(:real_stamp) { create(:stamp, original_file: "test.tif", extension: "tif", colorspace: "sRGB") }

    before do
      FileUtils.mkdir_p(Rails.root.join("storage", "stamps", real_stamp.uuid, "original"))
      FileUtils.cp(original_path.join("02-no_spot.tif"),
                   Rails.root.join("storage", "stamps", real_stamp.uuid, "original", "test.tif"))
    end

    after do
      FileUtils.rm_rf(Rails.root.join("storage", "stamps", real_stamp.uuid))
    end

    it "processes a stamp end-to-end" do
      described_class.perform_now(real_stamp.id)
      real_stamp.reload
      expect(real_stamp.status).to eq("processed")
      expect(real_stamp.preview_file).not_to be_nil
      expect(File.exist?(real_stamp.preview_file)).to be true
      dims = png_dimensions(real_stamp.preview_file)
      expect(dims).to eq([ 609, 486 ])
    end
  end
end
