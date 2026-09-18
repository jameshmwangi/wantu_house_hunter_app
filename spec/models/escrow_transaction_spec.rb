require "rails_helper"

RSpec.describe EscrowTransaction, type: :model do
  let(:appointment) { create(:viewing_appointment, fee_amount: 500) }
  let(:escrow) { appointment.escrow_transaction_or_create! }

  it "snapshots the booking fee and funds with a balanced ledger pair" do
    escrow.fund!(provider_reference: "provider-1", payload: { "payment_type" => "mpesa" })

    expect(escrow).to be_funded
    expect(escrow.amount_cents).to eq(50_000)
    expect(escrow.ledger_entries.pluck(:account, :entry_type, :amount_cents)).to contain_exactly(
      ["home_seeker_suspense", "debit", 50_000],
      ["escrow_holding", "credit", 50_000]
    )
    expect(appointment.reload.fee_status).to eq("paid")
    expect(escrow.confirmation_code).to match(/\A\d{6}\z/)
  end

  it "releases only with the confirmation code and creates agent payable" do
    escrow.fund!
    escrow.release!(code: escrow.confirmation_code)

    expect(escrow).to be_released
    expect(appointment.reload.status).to eq("completed")
    expect(appointment.agent.available_payable_cents(escrow.currency)).to eq(50_000)
  end

  it "records invalid confirmation attempts without releasing the escrow" do
    escrow.fund!

    expect { escrow.release!(code: "000000") }.to raise_error(EscrowTransaction::InvalidConfirmationCode)
    expect(escrow.reload.confirmation_attempts).to eq(1)
    expect(escrow).to be_funded
  end
end
