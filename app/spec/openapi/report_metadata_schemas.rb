require_relative "agency_schema_names"

module ReportMetadataSchemas
  def self.schemas
    agencies = Rails.application.config.client_agencies
    variants = agencies.client_agency_ids.each_with_object({}) do |agency_id, schemas|
      %i[v1 v2].each do |version|
        name = "ReportAgencyMetadata#{AgencySchemaNames::NAMES.fetch(agency_id)}#{version.to_s.upcase}"
        fields = agencies[agency_id].applicant_attribute_names(version: version)
        schemas[name] = {
          type: :object,
          additionalProperties: false,
          description: "Report metadata for #{agency_id} #{version}. Unavailable values are null; dates use YYYY-MM-DD. These are report fields, not invitation input fields.",
          properties: fields.to_h { |field| [ field, { type: %w[string null] } ] }
        }
      end
    end

    variants.merge(
      ReportAgencyPartnerMetadata: {
        description: "Agency-specific report metadata. The serializer uses V2 fields when individual_id is supplied, otherwise V1 fields. Each variant rejects undocumented fields.",
        anyOf: variants.keys.map { |name| { "$ref" => "#/components/schemas/#{name}" } }
      }
    )
  end
end
