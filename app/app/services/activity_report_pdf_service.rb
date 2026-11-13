class ActivityReportPdfService
  PDF_MARGIN = { top: 8, bottom: 8, left: 0, right: 0 }.freeze
  Report = Struct.new(:content, :file_name, :document_id, keyword_init: true)

  def initialize(activity_flow)
    @activity_flow = activity_flow
  end

  def generate
    html = I18n.with_locale(:en) do
      Activities::SubmitController.new.render_to_string(
        template: "activities/submit/show",
        formats: [ :pdf ],
        layout: "layouts/pdf",
        assigns: {
          report: ActivityPdfReport.new(flow: @activity_flow, caseworker: true)
        }
      )
    end

    Report.new(
      content: WickedPdf.new.pdf_from_string(html, margin: PDF_MARGIN),
      file_name: "HR1_Report_#{@activity_flow.completed_at.to_date.iso8601}.pdf",
      document_id: "REPORT-#{@activity_flow.id}"
    )
  end
end
