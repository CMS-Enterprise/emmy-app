# Determines whether an uploaded document has been cleared by the infra
# scanning pipeline by inspecting S3 state directly. Rails never scans or
# moves documents itself.
#
# * A document is "clean" once GuardDuty has scanned it and a Lambda has
#   copied it into the processed bucket (see emmy-infra's upload_processing
#   module and docs/upload-malware-scanning.md in that repo).
# * A document is "rejected" if a Lambda has tagged it in the
#   unscanned bucket.
# * Otherwise it's "pending", still waiting on the scan.
class DocumentScanStatusService
  REJECTION_TAG_KEY = "RejectionReason"

  # Known values the GuardDuty-result lambda in emmy-infra's
  # upload_processing module write to the RejectionReason tag.
  # Rails doesn't branch on these, see ActivitiesHelper#document_upload_error_message,
  # which falls back to a generic message if the tag value is unrecognized.
  REJECTION_REASON_ENCRYPTED = "encrypted"
  REJECTION_REASON_MALFORMED = "malformed"
  REJECTION_REASON_GUARDDUTY_THREAT = "guardduty_threat_found"

  PENDING = "pending"
  CLEAN = "clean"
  REJECTED = "rejected"

  class Result < Struct.new(:status, :rejection_reason)
    def rejected?
      status == REJECTED
    end
  end

  def self.call(blob)
    new(blob).call
  end

  def initialize(
    blob,
    unscanned_service: ActiveStorage::Blob.services.fetch(PresignedUploadService::SERVICE_NAME),
    processed_service: ActiveStorage::Blob.services.fetch(ProcessedDownloadService::SERVICE_NAME)
  )
    @blob = blob
    @unscanned_service = unscanned_service
    @processed_service = processed_service
  end

  def call
    return Result.new(CLEAN, nil) if processed_service.exist?(blob.key)

    reason = rejection_reason
    return Result.new(REJECTED, reason) if reason

    Result.new(PENDING, nil)
  end

  private

  attr_reader :blob, :unscanned_service, :processed_service

  # Local disk services (used in development/test, see config/storage.yml)
  # don't support tagging and don't actually scan anything, so there's
  # nothing to check beyond the processed-bucket lookup above.
  def rejection_reason
    return nil unless unscanned_service.respond_to?(:bucket)

    tags = unscanned_service.client.client.get_object_tagging(
      bucket: unscanned_service.bucket.name,
      key: blob.key
    ).tag_set

    tags.find { |tag| tag.key == REJECTION_TAG_KEY }&.value
  rescue Aws::Errors::ServiceError => e
    Rails.logger.warn("DocumentScanStatusService: could not check RejectionReason tag (#{e.class}: #{e.message})")
    nil
  end
end
