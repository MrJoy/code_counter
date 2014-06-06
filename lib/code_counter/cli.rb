module CodeCounter
  class CLI
    def self.expand_labeled_path(dir_with_label)
      components = dir_with_label.split(/\s*:\s*/)
      if components.length > 1
        (label, path) = *components
      else
        label = path = components.first
      end

      return [Pathname.new(path).expand_path.to_s, label]
    end
  end
end
