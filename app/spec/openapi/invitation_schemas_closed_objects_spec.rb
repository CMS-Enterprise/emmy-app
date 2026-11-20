require "swagger_helper"

RSpec.describe InvitationSchemas do
  let(:document) { RSpec.configuration.openapi_specs.fetch("openapi.json").deep_stringify_keys }
  let(:income_schema) { JSON.parse(Rails.root.join("spec/fixtures/income-report-2026-06-18.json").read) }

  # Traverse schema keywords only, never example payloads or OpenAPI metadata.
  def open_objects(schema, path)
    failures = []
    object = Array(schema["type"]).include?("object") || schema.key?("properties") || schema.key?("patternProperties")
    composed = schema.key?("anyOf") || schema.key?("oneOf")
    if object && !composed && schema["additionalProperties"] != false
      failures << path
    end
    %w[properties patternProperties].each do |keyword|
      schema.fetch(keyword, {}).each do |name, child|
        failures.concat(open_objects(child, "#{path}/#{keyword}/#{name}"))
      end
    end
    failures.concat(open_objects(schema["items"], "#{path}/items")) if schema["items"].is_a?(Hash)
    %w[anyOf oneOf allOf].each do |keyword|
      schema.fetch(keyword, []).each_with_index do |child, index|
        failures.concat(open_objects(child, "#{path}/#{keyword}/#{index}"))
      end
    end
    failures
  end

  it "closes every concrete OpenAPI component object, including nested objects" do
    failures = document.fetch("components").fetch("schemas").flat_map do |name, schema|
      open_objects(schema, name)
    end

    expect(failures).to be_empty
  end

  it "closes the inline JSON webhook response" do
    schema = document.dig("webhooks", ActivityReportWebhook::PATH, "post", "responses", "200", "content", "application/json", "schema")

    expect(open_objects(schema, "webhook response")).to be_empty
    validator = JSONSchemer.schema(schema)
    expect(validator.valid?({ "status" => "received" })).to be(true)
    expect(validator.valid?({ "status" => "received", "undocumented" => true })).to be(false)
  end

  it "closes legacy Income Report objects except the integration-defined metadata dictionary" do
    expect(open_objects(income_schema, "income")).to eq([ "income/properties/agency_partner_metadata" ])
  end
end
