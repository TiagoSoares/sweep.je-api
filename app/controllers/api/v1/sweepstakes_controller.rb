module Api
  module V1
    class SweepstakesController < BaseController
      before_action :set_sweepstake, only: %i[show update destroy lock draw reset_draw presentation]

      # GET /api/v1/sweepstakes
      def index
        sweepstakes = policy_scope(Sweepstake).order(created_at: :desc)
        render json: { sweepstakes: SweepstakeSerializer.new(sweepstakes).serializable_hash }
      end

      # POST /api/v1/sweepstakes
      def create
        return too_many_entries if entry_names_param.size > Sweepstake::MAX_ENTRIES

        sweepstake = current_user.sweepstakes.new(sweepstake_params)
        sweepstake.competition_template = selected_template # provenance (may be nil)
        populate_entries(sweepstake)
        # Inherit the template's prediction questions when none were supplied.
        if sweepstake.prediction_fields.empty? && selected_template
          sweepstake.prediction_fields = selected_template.prediction_fields
        end
        authorize sweepstake

        if sweepstake.save
          sweepstake.schedule_auto_draw!
          render json: { sweepstake: SweepstakeSerializer.new(sweepstake).serializable_hash }, status: :created
        else
          render_errors(sweepstake)
        end
      end

      # GET /api/v1/sweepstakes/:id
      def show
        render json: { sweepstake: SweepstakeSerializer.new(@sweepstake).serializable_hash }
      end

      # PATCH /api/v1/sweepstakes/:id
      def update
        if @sweepstake.update(sweepstake_params)
          @sweepstake.schedule_auto_draw! if @sweepstake.saved_change_to_draw_at?
          render json: { sweepstake: SweepstakeSerializer.new(@sweepstake).serializable_hash }
        else
          render_errors(@sweepstake)
        end
      end

      # DELETE /api/v1/sweepstakes/:id
      def destroy
        @sweepstake.destroy
        head :no_content
      end

      # POST /api/v1/sweepstakes/:id/lock — close registration ahead of the draw.
      def lock
        return render_conflict("Sweepstake has already been drawn") if @sweepstake.drawn?

        @sweepstake.update!(status: :locked)
        render json: { sweepstake: SweepstakeSerializer.new(@sweepstake).serializable_hash }
      end

      # POST /api/v1/sweepstakes/:id/draw — run the draw now (manual/early, §4.3).
      def draw
        DrawRunner.new(@sweepstake, run_by: current_user, trigger: :manual).call
        @sweepstake.reload
        render json: { sweepstake: SweepstakeSerializer.new(@sweepstake).serializable_hash }
      rescue DrawRunner::NotDrawable => e
        render_error(status: :conflict, code: "not_drawable", detail: e.message)
      end

      # POST /api/v1/sweepstakes/:id/reset_draw — clear allocations and reopen (§4.3).
      def reset_draw
        return render_conflict("This sweepstake has not been drawn") unless @sweepstake.drawn?

        @sweepstake.transaction do
          @sweepstake.draws.destroy_all
          @sweepstake.update!(status: :open)
        end
        @sweepstake.schedule_auto_draw!
        render json: { sweepstake: SweepstakeSerializer.new(@sweepstake.reload).serializable_hash }
      end

      # GET /api/v1/sweepstakes/:id/presentation — data for the live-draw reveal:
      # the teams (rank order, with flags), the players, and — once drawn — which
      # team went to which player, in reveal order.
      def presentation
        entries = @sweepstake.entries.order(:position, :id)
        participants = @sweepstake.participants.order(:created_at, :id)

        allocations =
          if @sweepstake.drawn? && (draw = @sweepstake.current_draw)
            by_entry = draw.allocations.includes(:participant).index_by(&:entry_id)
            entries.map do |e|
              { entry_id: e.public_id, participant_id: by_entry[e.id]&.participant&.public_id }
            end
          end

        render json: {
          presentation: {
            status: @sweepstake.status,
            name: @sweepstake.name,
            entries: entries.map { |e| { id: e.public_id, name: e.name, flag: entry_flag(e) } },
            participants: participants.map { |p| { id: p.public_id, name: p.name } },
            allocations: allocations
          }
        }
      end

      private

      def entry_flag(entry)
        entry.metadata.is_a?(Hash) ? entry.metadata["flag"] : nil
      end

      def set_sweepstake
        @sweepstake = current_user.sweepstakes.find_by_public_id!(params[:id])
        authorize @sweepstake
      end

      def sweepstake_params
        params.require(:sweepstake).permit(
          :name, :description, :draw_at, :timezone, :max_participants, :participants_public,
          prediction_fields: []
        )
      end

      # Accepts `entries` as an array of strings or { name: } objects (§4.1 manual).
      def entry_names_param
        raw = params.dig(:sweepstake, :entries)
        return [] unless raw.is_a?(Array)

        raw.filter_map do |e|
          # Each element is either a bare string or a { name: } object (which
          # arrives as ActionController::Parameters, not a plain Hash).
          name = e.is_a?(String) ? e : (e[:name] || e["name"])
          name.to_s.strip.presence
        end
      end

      # Manual `entries` are the source of truth when given; otherwise the entries
      # come from the selected template (§5). Provenance is recorded either way.
      def populate_entries(sweepstake)
        names = entry_names_param
        if names.any?
          names.each_with_index { |name, i| sweepstake.entries.build(name:, position: i + 1) }
        elsif sweepstake.competition_template
          sweepstake.competition_template.build_entries_for(sweepstake)
        end
      end

      def selected_template
        return @selected_template if defined?(@selected_template)

        slug = params.dig(:sweepstake, :template_slug)
        @selected_template = slug.present? ? CompetitionTemplate.published.find_by(slug:) : nil
      end

      def render_conflict(detail)
        render_error(status: :conflict, code: "conflict", detail:)
      end

      def too_many_entries
        render_error(status: :unprocessable_content, code: "too_many_entries",
                     detail: "A sweepstake can have at most #{Sweepstake::MAX_ENTRIES} entries")
      end
    end
  end
end
