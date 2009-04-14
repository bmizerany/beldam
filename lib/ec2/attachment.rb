require 'json'
require 'tempfile'
require 'socket'
require 'timeout'

module EC2

  class Attachment

    def self.fields(*names)
      return @fields if names.empty?
      @fields = names
      @fields.freeze
      attr_accessor *names
    end

    fields "id", "instance_id", "device", "state", "created_at"

    def self.from_line(line)
      values = line.split("\t")[1..-1]
      fields.inject(new) {|m,f| m[f] = values.shift; m}
    end

    def self.all(reload=false)
      @attachments = nil if reload
      @attachments ||= c(:describe_volumes).
        split("\n").
        grep(/ATTACHMENT/).
        map { |i| from_line(i) }
    end

    def self.find(id, reload=false)
      all(reload).find {|i| i["id"] == id}
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

    def [](f)
      fail "Invalid field #{f}" unless fields.include?(f.to_s)
      send(f)
    end

    def []=(f, v)
      fail "Invalid field #{f}" unless fields.include?(f.to_s)
      send(f.to_s + "=", v)
    end

    def detach
      volume.detach
    end

    def volume
      Volume.all.find {|v| v.id == self.id}
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
      update(self.class.find(id, true))
    end

  end

end
