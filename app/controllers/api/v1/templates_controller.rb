module Api
  module V1
    # Public, read-only access to published competition templates (for the create
    # form). No auth required.
    class TemplatesController < PublicController
      # GET /api/v1/templates
      def index
        templates = CompetitionTemplate.published
                                       .includes(:template_entries)
                                       .order(:year, :name)
        render json: { templates: CompetitionTemplateSummarySerializer.new(templates).serializable_hash }
      end

      # GET /api/v1/templates/:slug
      def show
        template = CompetitionTemplate.published
                                      .includes(:template_entries)
                                      .find_by!(slug: params[:slug])
        render json: { template: CompetitionTemplateSerializer.new(template).serializable_hash }
      end
    end
  end
end
