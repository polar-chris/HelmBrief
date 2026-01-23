default_platform(:ios)

platform :ios do
  lane :beta do
    api_key = app_store_connect_api_key(
      key_id: ENV["FASTLANE_KEY_ID"],
      issuer_id: ENV["FASTLANE_ISSUER_ID"],
      key_content: ENV["FASTLANE_KEY"],
      is_key_content_base64: false
    )

    match(
      type: "appstore",
      git_url: ENV["MATCH_GIT_URL"],
      api_key: api_key
    )

    # Always bump build number (TestFlight requires unique builds)
    increment_build_number(build_number: ENV["GITHUB_RUN_NUMBER"])

    build_app(
      scheme: "HelmBrief",
      export_method: "app-store"
    )

    upload_to_testflight(
      api_key: api_key,
      skip_waiting_for_build_processing: true
    )
  end
end
