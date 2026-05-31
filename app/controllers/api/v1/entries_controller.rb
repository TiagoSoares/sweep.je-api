module Api
  module V1
    class EntriesController < BaseController
      before_action :set_sweepstake, only: %i[index create bulk]
      before_action :set_entry, only: %i[update destroy]
      before_action :guard_editable!, only: %i[create bulk update destroy]

      # GET /api/v1/sweepstakes/:sweepstake_id/entries
      def index
        render json: { entries: EntrySerializer.new(@sweepstake.entries).serializable_hash }
      end

      # POST /api/v1/sweepstakes/:sweepstake_id/entries
      def create
        entry = @sweepstake.entries.new(entry_params)
        if entry.save
          render json: { entry: EntrySerializer.new(entry).serializable_hash }, status: :created
        else
          render_errors(entry)
        end
      end

      # POST /api/v1/sweepstakes/:sweepstake_id/entries/bulk — paste a list (§8).
      def bulk
        names = Array(params[:names]).filter_map { |n| n.to_s.strip.presence }
        return render_error(status: :unprocessable_content, code: "invalid", detail: "No entry names given") if names.empty?

        if @sweepstake.entries.count + names.size > Sweepstake::MAX_ENTRIES
          return render_error(status: :unprocessable_content, code: "too_many_entries",
                              detail: "A sweepstake can have at most #{Sweepstake::MAX_ENTRIES} entries")
        end

        created = @sweepstake.transaction do
          start = (@sweepstake.entries.maximum(:position) || 0)
          names.each_with_index.map do |name, i|
            @sweepstake.entries.create!(name:, position: start + i + 1)
          end
        end
        render json: { entries: EntrySerializer.new(created).serializable_hash }, status: :created
      end

      # PATCH /api/v1/entries/:id
      def update
        if @entry.update(entry_params)
          render json: { entry: EntrySerializer.new(@entry).serializable_hash }
        else
          render_errors(@entry)
        end
      end

      # DELETE /api/v1/entries/:id
      def destroy
        @entry.destroy
        head :no_content
      end

      private

      def set_sweepstake
        @sweepstake = current_user.sweepstakes.find_by_public_id!(params[:sweepstake_id])
        authorize @sweepstake, :update?
      end

      def set_entry
        @entry = Entry.find_by_public_id!(params[:id])
        @sweepstake = @entry.sweepstake
        authorize @entry
      end

      # Entries are editable until the draw runs (§14); halts the action if drawn.
      def guard_editable!
        return unless @sweepstake.drawn?

        render_error(status: :conflict, code: "conflict",
                     detail: "Entries can't be changed after the draw")
      end

      def entry_params
        params.require(:entry).permit(:name, :position, metadata: {})
      end
    end
  end
end
