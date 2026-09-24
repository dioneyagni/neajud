# Named fakes for uploaded files in specs.

# Wraps a real Rack upload but reports a tempfile larger than any real fixture,
# to exercise the 1GB limit without writing 1GB to disk.
# Usage: OversizeUpload.new(fixture_file_upload("02-no_spot.tif"), size: 2.gigabytes)
class OversizeUpload
  FakeTempfile = Struct.new(:path, :size)

  def initialize(upload, size:)
    @upload = upload
    @size = size
  end

  def original_filename = @upload.original_filename
  def content_type = @upload.content_type
  def read = @upload.read
  def tempfile = FakeTempfile.new(@upload.tempfile.path, @size)
end
