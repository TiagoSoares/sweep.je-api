class ApplicationController < ActionController::API
  include Pundit::Authorization

  # Consistent error envelope: { "errors": [{ "code", "detail", "field" }] } (§8).
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  private

  def render_error(status:, code:, detail:, field: nil)
    error = { code:, detail: }
    error[:field] = field if field
    render json: { errors: [error] }, status:
  end

  def render_errors(records_or_messages, status: :unprocessable_content, code: "invalid")
    messages = records_or_messages.respond_to?(:errors) ? records_or_messages.errors : records_or_messages
    errors =
      if messages.respond_to?(:map) && messages.respond_to?(:each)
        messages.map { |e| { code:, detail: e.respond_to?(:full_message) ? e.full_message : e.to_s, field: e.try(:attribute) } }
      else
        [{ code:, detail: messages.to_s }]
      end
    render json: { errors: }, status:
  end

  def render_not_found(_exception = nil)
    render_error(status: :not_found, code: "not_found", detail: "Resource not found")
  end

  def render_unprocessable(exception)
    render_errors(exception.record, status: :unprocessable_content)
  end

  def render_forbidden(_exception = nil)
    render_error(status: :forbidden, code: "forbidden", detail: "You are not allowed to perform this action")
  end

  def render_bad_request(exception)
    render_error(status: :bad_request, code: "bad_request", detail: exception.message)
  end
end
