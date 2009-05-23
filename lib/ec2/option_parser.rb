module EC2

  class OptionParser

    def initialize(defaults={})
      @defaults = defaults
      yield @defaults if block_given?
    end

    def parse(options)
      @defaults.merge(options).inject([]) {|m,(k,v)|
        key = (k.to_s.size > 1 ? "--" : "-") << k.to_s
        m << key << v
      }
    end

  end

end
