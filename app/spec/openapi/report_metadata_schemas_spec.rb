require "rails_helper"
require_relative "report_metadata_schemas"

RSpec.describe ReportMetadataSchemas do
  let(:document) do
    JSONSchemer.openapi(JSON.parse({
      openapi: "3.1.0", info: { title: "Report metadata", version: "v1" }, paths: {},
      components: { schemas: described_class.schemas }
    }.to_json))
  end
  let(:schema) { document.schema("ReportAgencyPartnerMetadata") }
  let(:metadata) do
    {
      "individual_id" => "INDIVIDUAL-123", "first_name" => "Jane", "middle_name" => nil,
      "last_name" => "Doe", "case_number" => "EXAMPLE-123", "date_of_birth" => "1990-01-15"
    }
  end

  it "accepts the existing V2 report fields that differ from invitation inputs" do
    expect(schema.validate(metadata).to_a).to be_empty
  end

  it "rejects undocumented fields through the composed metadata schema" do
    expect(schema.valid?(metadata.merge("undocumented" => true))).to be(false)
  end

  it "matches every agency's serialized field set for both versions" do
    Rails.application.config.client_agencies.client_agency_ids.each do |agency_id|
      %i[v1 v2].each do |version|
        payload = CbvApplicant.build_agency_partner_metadata(agency_id, version: version) { "synthetic" }
        name = "ReportAgencyMetadata#{agency_id.camelize}#{version.to_s.upcase}"
        variant = document.schema(name)

        expect(described_class.schemas.fetch(name)[:properties].keys.map(&:to_s)).to match_array(payload.keys)
        expect(variant.validate(payload).to_a).to be_empty, name
        expect(variant.valid?(payload.merge("undocumented" => true))).to be(false), name
      end
    end
  end

  it "preserves nullable metadata values emitted by report serializers" do
    nullable_metadata = metadata.transform_values { nil }

    expect(schema.validate(nullable_metadata).to_a).to be_empty
  end
end
