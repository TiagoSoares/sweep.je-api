module Api
  module V1
    module Admin
      # Platform-admin CRUD for competition templates (§5).
      class TemplatesController < BaseController
        before_action :set_template, only: %i[show update destroy]

        # GET /api/v1/admin/templates — all templates, any status.
        def index
          templates = CompetitionTemplate.includes(:template_entries).order(:year, :name)
          render json: { templates: CompetitionTemplateSummarySerializer.new(templates).serializable_hash }
        end

        # GET /api/v1/admin/templates/:slug
        def show
          render json: { template: CompetitionTemplateSerializer.new(@template).serializable_hash }
        end

        # POST /api/v1/admin/templates
        def create
          template = CompetitionTemplate.new(template_params)
          assign_entries(template, entries_param) if entries_param
          if template.save
            render json: { template: CompetitionTemplateSerializer.new(template).serializable_hash }, status: :created
          else
            render_errors(template)
          end
        end

        # PATCH /api/v1/admin/templates/:slug
        def update
          @template.assign_attributes(template_params)
          # Replacing entries is opt-in: only when an `entries` array is supplied.
          if entries_param
            @template.template_entries.destroy_all
            assign_entries(@template, entries_param)
          end
          if @template.save
            render json: { template: CompetitionTemplateSerializer.new(@template).serializable_hash }
          else
            render_errors(@template)
          end
        end

        # DELETE /api/v1/admin/templates/:slug
        def destroy
          @template.destroy
          head :no_content
        end

        private

        def set_template
          @template = CompetitionTemplate.find_by!(slug: params[:slug])
        end

        def template_params
          params.require(:template).permit(:name, :slug, :category, :year, :status, prediction_fields: [])
        end

        # Accepts `entries` as strings or { name:, metadata: } objects.
        def entries_param
          raw = params.dig(:template, :entries)
          raw.is_a?(Array) ? raw : nil
        end

        def assign_entries(template, entries)
          entries.each_with_index do |e, i|
            if e.is_a?(String)
              template.template_entries.build(name: e.strip, position: i + 1)
            else
              template.template_entries.build(
                name: (e[:name] || e["name"]).to_s.strip,
                position: e[:position] || i + 1,
                metadata: e[:metadata] || e["metadata"]
              )
            end
          end
        end
      end
    end
  end
end
