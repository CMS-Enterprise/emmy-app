Grover.configure do |config|
  config.options = {
    # Grover intercepts this navigation to supply the report HTML. Start with
    # HTTPS to avoid an upgrade request bypassing that one-time interception.
    display_url: "https://emmy-pdf.invalid/",
    format: "A4",
    tagged: true,
    outline: true,
    print_background: true,
    emulate_media: "screen",
    viewport: { width: 1280, height: 1024 },
    wait_until: "networkidle0",
    timeout: 30_000,
    executable_path: ENV["PUPPETEER_EXECUTABLE_PATH"],
    launch_args: [ "--disable-dev-shm-usage" ]
  }.compact
end
