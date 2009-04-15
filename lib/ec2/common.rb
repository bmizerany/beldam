module EC2

  module Common

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def fields(*names)
        return @fields if names.empty?
        @fields = names
        @fields.freeze
        attr_accessor *names
      end

      def selector(cmd, options={})
        @describe_command = cmd
        @idregex =
          options.fetch(:identification_regex)
      end

      def from_line(line)
        values = line.split("\t")[1..-1]
        fields.inject(new) {|m,f| m[f] = values.shift; m}
      end

      def all
        c(@describe_command).
          split("\n").
          grep(@idregex).
          map { |i| from_line(i) }
      end

      def find(id)
        all.find {|i| i["id"] == id}
      end

      def c(cmd, *args)
        cmd1 = "ec2-#{cmd.to_s.tr('_', '-')} #{args.join(" ")}"
        `#{cmd1}`
      end

    end

    def initialize(fields = nil)
      update(fields) if fields
      yield self if block_given?
    end

    def fields
      self.class.fields
    end

    def update(hash)
      fields.each {|f| self[f.to_s] = hash[f.to_s]}
      self
    end

    def [](f)
      fail "Invalid field #{f}" unless fields.include?(f.to_s)
      send(f)
    end

    def []=(f, v)
      fail "Invalid field #{f}" unless fields.include?(f.to_s)
      send(f.to_s + "=", v)
    end

    def c(*args)
      self.class.c(*args)
    end

    def to_hash
      fields.inject({}) {|m,f| m[f] = self[f]; m}
    end

    def to_a
      fields.map {|f| self[f]}
    end

    def reload!
      update(self.class.find(id))
    end

  end

end
