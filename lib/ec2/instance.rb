require 'time'
require 'rubygems'
require 'json'
require 'tempfile'
require 'socket'
require 'timeout'

module EC2

  class Instance

    def self.fields(*names)
      return @fields if names.empty?
      @fields = names
      @fields.freeze
      attr_accessor *names
    end

    fields "id", "ami_id", "public_dns", "private_dns",
      "state", "key", "index", "codes", "type",
      "created_at", "zone"

    def self.from_line(line)
      values = line.split("\t")[1..-1]
      fields.inject(new) {|m,f| m[f] = values.shift; m}
    end

    def self.all(reload=false)
      @instances = nil if reload
      @instances ||= c(:describe_instances).
        split("\n").
        grep(/INSTANCE/).
        map { |i| from_line(i) }
    end

    def self.run(image_ids, *args)
      data = args.last.is_a?(Hash) ? args.pop : {}
      t = Tempfile.open("beldam")
      t << data.to_json
      t.close
      c(:run_instances, *(Array(image_ids) + ["-f", t.path] + args)).
        split("\n").
        grep(/INSTANCE/).
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

    def created_at
      Time.parse(@created_at) rescue nil
    end

    def cmd(c, i="~/.ssh/id_rsa")
      system(ssh_cmd(c, i))
    end

    def cmdo(c, i="~/.ssh/id_rsa")
      `#{ssh_cmd(c, i)}`
    end

    def ssh_cmd(c, i="~/.ssh/id_rsa")
      "ssh -i #{i} root@#{public_dns} '#{c}'"
    end

    def scp(from, to, i="~/.ssh/id_rsa")
      system("scp -i #{i} #{from} root@#{self.public_dns}:#{to}")
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

    def active?
      !public_dns.nil? && !public_dns.empty?
    end

    def ssh?
      @ssh ||= begin
        if running?
          TCPSocket.new(self.public_dns, 22).close
          true
        else
          false
        end
      rescue
        false
      end
    end

    def running?
      self.state == "running"
    end

    def pending?
      self.state == "pending"
    end

    def destroyed?
      self.state == "terminated" ||
        self.state.nil? ||
        self.state.empty?
    end

    def console_log
      c(:get_console_output, self.id)
    end

  end

end
