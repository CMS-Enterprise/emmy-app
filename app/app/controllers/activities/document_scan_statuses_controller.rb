module Activities
  class DocumentScanStatusesController < Activities::BaseController
    def show
      blob = ActiveStorage::Blob.find_signed(params[:signed_id])

      return head :not_found if blob.nil? || blob.service_name != PresignedUploadService::SERVICE_NAME.to_s

      result = DocumentScanStatusService.call(blob)

      render json: {
        status: result.status,
        error: result.rejected? ? helpers.document_upload_error_message(current_agency, result.rejection_reason) : nil
      }
    end
  end
end
