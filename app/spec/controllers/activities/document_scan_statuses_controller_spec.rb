require "rails_helper"

RSpec.describe Activities::DocumentScanStatusesController, type: :controller do
  include_context "activity_hub"

  let(:activity_flow) { create(:activity_flow) }
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4"),
      filename: "document.pdf",
      content_type: "application/pdf",
      service_name: PresignedUploadService::SERVICE_NAME
    )
  end

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  def stub_scan_result(status, reason = nil)
    allow(DocumentScanStatusService).to receive(:call)
      .and_return(DocumentScanStatusService::Result.new(status, reason))
  end

  describe "GET #show" do
    it "reports a pending scan" do
      stub_scan_result(DocumentScanStatusService::PENDING)

      get :show, params: { signed_id: blob.signed_id }, format: :json

      expect(response.parsed_body).to eq("status" => "pending", "error" => nil)
    end

    it "reports a clean scan" do
      stub_scan_result(DocumentScanStatusService::CLEAN)

      get :show, params: { signed_id: blob.signed_id }, format: :json

      expect(response.parsed_body).to eq("status" => "clean", "error" => nil)
    end

    it "reports a rejected scan with a user-facing message" do
      stub_scan_result(DocumentScanStatusService::REJECTED, :encrypted)

      get :show, params: { signed_id: blob.signed_id }, format: :json

      json = response.parsed_body
      expect(json["status"]).to eq("rejected")
      expect(json["error"]).to eq(I18n.t("activities.document_uploads.new.errors.encrypted"))
    end

    it "404s for an unknown signed id" do
      get :show, params: { signed_id: "bogus" }, format: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
