require "rails_helper"

RSpec.describe "Admin verifications", type: :request do
  let!(:user) { create_admin }
  let!(:site) { cafe_site }

  before { sign_in(user) }

  def request_for(slot_key, priority: 290, question: "営業時間を教えてください。")
    site.verification_requests.create!(request_type: "initial", slot_key: slot_key,
                                       question: question, priority: priority)
  end

  it "asks in priority order and never shows a slot key" do
    request_for("cadence", priority: 103, question: "更新の頻度について聞かせてください。")
    request_for("hours", priority: 290)

    get admin_verifications_path

    expect(response.body.index("営業時間")).to be < response.body.index("更新の頻度")
    expect(response.body).not_to include("hours")
    expect(response.body).not_to include("cadence")
  end

  it "says there is nothing to ask when the site is complete" do
    get admin_verifications_path

    expect(response.body).to include("お聞きしたいことはありません")
  end

  it "records an answer verbatim and queues the extraction" do
    request = request_for("hours")

    expect {
      post answer_admin_verification_path(request), params: { answer: "朝7時から夕方5時まで開けています" }
    }.to have_enqueued_job(Verification::ProcessAnswersJob)

    expect(response).to redirect_to(admin_verifications_path)
    event = request.reload.events.sole
    expect(event.notes).to eq("朝7時から夕方5時まで開けています")
    expect(event.person_id).to eq("user:#{user.id}")
    expect(request.status).to eq("answered")
  end

  it "refuses an empty answer without closing the question" do
    request = request_for("hours")

    post answer_admin_verification_path(request), params: { answer: "   " }

    expect(request.reload.status).to eq("open")
    expect(request.events).to be_empty
  end

  it "lets the owner put a question aside without deleting it" do
    request = request_for("hours")

    post skip_admin_verification_path(request)

    expect(request.reload.status).to eq("closed")
    expect(request.events.sole.result).to eq("skipped")
    expect(VerificationRequest.find_by(id: request.id)).to be_present
  end

  it "will not take a second answer to a question already answered" do
    request = request_for("hours")
    request.record_answer!("7時から", person_id: "user:#{user.id}")

    post answer_admin_verification_path(request), params: { answer: "やっぱり8時から" }

    expect(response).to have_http_status(:not_found), "only open questions accept answers"
    expect(request.reload.events.count).to eq(1)
  end
end
