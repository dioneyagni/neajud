# Estimates the work time behind each file of an upload batch: the gap
# between the previous upload (before this batch started) and the batch
# start, split evenly across the batch's files. 0 for the very first upload.
#
# Usage: UploadTimeEstimator.call(batch_started_at: Time.parse(ts), batch_size: 3) # => 1200
class UploadTimeEstimator
  def self.call(batch_started_at:, batch_size:)
    new(batch_started_at, batch_size).call
  end

  def initialize(batch_started_at, batch_size)
    @batch_started_at = batch_started_at
    @batch_size = batch_size
  end

  def call
    last_upload_at = Arquivo.where("created_at < ?", @batch_started_at).maximum(:created_at)
    return 0 unless last_upload_at

    interval = (@batch_started_at - last_upload_at).to_i
    [ interval / @batch_size, 0 ].max
  end
end
