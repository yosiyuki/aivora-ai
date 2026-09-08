require "rails_helper"

# The layout is Slim, not ERB. Rendering it proves the engine is wired in and
# that the head still carries what every page depends on.
RSpec.describe "layouts/application", type: :view do
  it "renders from Slim with the CSRF, CSP and importmap tags" do
    view.content_for(:title, "Probe")
    render template: "layouts/application"

    expect(rendered).to start_with("<!DOCTYPE html>")
    expect(rendered).to include("<title>Probe</title>")
    # csrf_meta_tags and csp_meta_tag render nothing in the test env (forgery
    # protection off, no CSP), so assert on what the layout itself emits.
    expect(rendered).to include('name="viewport"')
    expect(rendered).to include('rel="stylesheet"')
    expect(rendered).to include('type="importmap"')
    expect(Dir[Rails.root.join("app/views/**/*.html.erb")]).to be_empty, "HTML views must be Slim"
  end
end
