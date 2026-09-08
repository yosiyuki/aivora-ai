require "rails_helper"

# Solid Queue supervisors, dispatchers and workers register themselves in
# solid_queue_processes with a serialized metadata column. A JSON gem that is
# incompatible with ActiveSupport breaks that silently: the process stays up
# but never registers, so jobs are never claimed. This caught json 3.0.
RSpec.describe "Solid Queue process registration" do
  it "persists a dispatcher with serialized metadata" do
    process = SolidQueue::Process.register(
      kind: "Dispatcher", name: "spec-dispatcher", pid: Process.pid, hostname: "spec",
      supervisor: nil, metadata: { polling_interval: 1, batch_size: 500 }
    )
    expect(process).to be_persisted
    expect(process.reload.metadata).to include("polling_interval" => 1)
  ensure
    process&.destroy
  end
end
