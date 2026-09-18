module Api
  module V1
    class VisitsController < ApplicationController
      before_action :authenticate_user!

      def confirm
        appointment = current_user.agent_appointments.find(params[:id])
        escrow = appointment.escrow_transaction
        escrow.release!(code: params.require(:code))

        render json: {
          status: escrow.status,
          available_payable_cents: current_user.available_payable_cents(escrow.currency),
          currency: escrow.currency
        }
      rescue EscrowTransaction::InvalidTransition, EscrowTransaction::InvalidConfirmationCode => error
        render json: { error: error.message }, status: :unprocessable_entity
      end
    end
  end
end
