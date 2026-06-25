# frozen_string_literal: true

module Fatty
  module ProgressApi
    # Create a transient status-line progress indicator.
    # For style :spinner, total may be omitted for indeterminate progress.
    def add_progress(
          label: Progress::DEFAULT_LABEL,
          total: nil,
          style: Progress::DEFAULT_STYLE,
          role: Progress::DEFAULT_ROLE,
          width: Progress::DEFAULT_WIDTH
        )
      @progress = Progress.new(
        terminal: terminal,
        label: label,
        total: total,
        style: style,
        role: role,
        width: width,
      )
    end
  end
end
