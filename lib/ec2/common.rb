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
          options.fetch(:identification_regex) {
            Regexp.new(name.upcase.split("::").last)
          }
      end

      def from_line(line)
        values = line.chomp.split("\t")[1..-1]
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
        `#{cmd1}`.tap {|out|
          if $? != 0
            fail "ERROR: #{out}"
          end
        }
      end

      def returnify(o)
        array = Array(o)
        return array.first if array.size <= 1
        array
      end

    end

    def initialize(fields = nil)
      update(fields) if fields
      yield self if block_given?
    end

    def wait!(*for_what)
      Timeout.timeout(60) do
        sleep(1) && reload! until for_what.all? { |what|
          send("#{what}?")
        }
      end
      self
    end

    def fields
      self.class.fields
    end

    def update(o)
      case o
      when String
        update(self.class.from_line(o))
      when self.class
        update(o.to_hash)
      when Hash
        fields.each {|f| self[f.to_s] = o[f.to_s]}
      end
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

    def inspect
      data = fields.map {|k| [k,self[k].inspect] * ":"} * " "
      "<#{self.class.name} #{data}>"
    end

  end

end
