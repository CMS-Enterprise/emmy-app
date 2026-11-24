require "rails_helper"
require "active_storage/service/s3_service"

RSpec.describe DocumentScanStatusService do
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4"),
      filename: "document.pdf",
      content_type: "application/pdf",
      service_name: PresignedUploadService::SERVICE_NAME
    )
  end
  let(:processed_service) { ActiveStorage::Blob.services.fetch(ProcessedDownloadService::SERVICE_NAME) }
  let(:not_yet_processed) { instance_double(ActiveStorage::Service, exist?: false) }

  describe ".call" do
    it "reports clean once the object exists in the processed bucket" do
      processed_service.upload(blob.key, StringIO.new("%PDF-1.4"))

      result = described_class.call(blob)

      expect(result.status).to eq(described_class::CLEAN)
      expect(result).not_to be_rejected
    end

    it "reports pending when not yet processed and the unscanned service can't be tag-checked (local disk, used in dev/test)" do
      result = described_class.new(blob, processed_service: not_yet_processed).call

      expect(result.status).to eq(described_class::PENDING)
      expect(result.rejection_reason).to be_nil
    end
  end

  context "with an S3-backed unscanned service" do
    let(:s3_client) { Aws::S3::Client.new(stub_responses: true, region: "us-east-1") }
    let(:unscanned_service) { ActiveStorage::Service::S3Service.new(bucket: "quarantine-bucket", client: s3_client) }

    def call
      described_class.new(
        blob,
        unscanned_service: unscanned_service,
        processed_service: not_yet_processed
      ).call
    end

    it "reports rejected with the tagged reason" do
      s3_client.stub_responses(:get_object_tagging, tag_set: [ { key: "RejectionReason", value: "UNSUPPORTED" } ])

      result = call

      expect(result.status).to eq(described_class::REJECTED)
      expect(result.rejection_reason).to eq("UNSUPPORTED")
      expect(result).to be_rejected
    end

    it "reports pending when no rejection tag is present yet" do
      s3_client.stub_responses(:get_object_tagging, tag_set: [])

      expect(call.status).to eq(described_class::PENDING)
    end

    it "reports pending when the object no longer exists in the unscanned bucket" do
      s3_client.stub_responses(:get_object_tagging, "NoSuchKey")

      expect(call.status).to eq(described_class::PENDING)
    end

    it "reports pending, without raising, when the tag can't be read yet (e.g. IAM not granted)" do
      s3_client.stub_responses(:get_object_tagging, "AccessDenied")

      expect(call.status).to eq(described_class::PENDING)
    end
  end
end
