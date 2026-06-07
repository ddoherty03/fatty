module Fatty
  module ProgressApi
    # Create a transient status-line progress indicator.
    # For style :spinner, total may be omitted for indeterminate progress.
    def progress(label:, total: nil, style: :percent, role: :info, width: 40)
      Progress.new(
        terminal: self,
        label: label,
        total: total,
        style: style,
        role: role,
        width: width,
      )
    end
  end
end
