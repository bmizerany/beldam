require 'json'
require 'tempfile'
require 'socket'
require 'timeout'

module EC2

  class Volume

    def self.fields(*names)
      return @fields if names.empty?
      @fields = names
      @fields.freeze
      attr_accessor *names
    end

    fields "id", "size", "snapshot", "zone",
      "state", "created_at"

    def self.from_line(line)
      values = line.split("\t")[1..-1]
      fields.inject(new) {|m,f| m[f] = values.shift; m}
    end

    def self.all(reload=false)
      @volumes = nil if reload
      @volumes ||= c(:describe_volumes).
        split("\n").
        grep(/VOLUME/).
        map { |i| from_line(i) }
    end

    def self.create(options={})
      args = []
      args += ["--size", options[:size]] if options.has_key?(:size)
      args += ["--snapshot", options[:snapshot]] if options.has_key?(:snapshot)
      args += ["-z", options.fetch("zone") { "us-east-1a" }]

      c(:create_volume, *args).
        split("\n").
        grep(/VOLUME/).
        map {|i| from_line(i)}
    end

    def self.find(id, reload=false)
      all(reload).find {|i| i["id"] == id}
    end

    def self.destroy(*ids)
      return if ids.length == 0
      c(:terminate_instances, *ids.flatten)
    end

    def self.c(cmd, *args)
      cmd1 = "ec2-#{cmd.to_s.tr('_', '-')} #{args.join(" ")}"
      `#{cmd1}`
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

    def attach(instance, device="/dev/sdh")
      c(:attach_volume, self.id, "-i", instance.id, "-d", device)
    end

    def [](f)
      fail "Invalid field #{f}" unless fields.include?(f.to_s)
      send(f)
    end

    def []=(f, v)
      fail "Invalid field #{f}" unless fields.include?(f.to_s)
      send(f.to_s + "=", v)
    end

    def destroy
      self.class.destroy(id)
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

    def wait!(*for_what)
      Timeout.timeout(60) do
        sleep(1) && reload! until for_what.all? { |what|
          send("#{what}?")
        }
      end
      self
    end

    def reload!
      update(self.class.find(id, true))
    end

    def creating?
      self.state == "creating"
    end

    def available?
      self.state == "available"
    end

    def in_use?
      self.sate == "in-use"
    end

  end

end
