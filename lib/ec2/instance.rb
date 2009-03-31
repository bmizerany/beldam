require 'time'
require 'rubygems'
require 'json'
require 'tempfile'
require 'socket'

module EC2

  class Instance

    attr_accessor :slot, :id, :ssh, :ami_id,
      :public_dns, :private_dns, :state, 
      :key, :index, :codes, :type, 
      :raw_created_at, :zone

    def self.fields
      [
       "id",
       "ami_id",
       "public_dns",
       "private_dns",
       "state",
       "key",
       "index",
       "codes",
       "type",
       "created_at",
       "zone"
      ]
    end

    def self.from_line(line)
      new(line.split("\t")[1..-1])
    end

    def self.all(force=false, &filter)
      filter ||= lambda { true }
      if !@instances || force
        @instances = \
        c(:describe_instances).
          split("\n").
          grep(/INSTANCE/).
          map { |i| from_line(i) }
      else
        @instances
      end.select(&filter)
    end

    def self.find(id, force=false)
      found = all(force).find { |i| i.id == id }
      fail "Instance #{id} not found" unless found
      found
    end

    def self.run(type, *args)
      data = args.last.is_a?(Hash) ? args.pop : {}
      t = Tempfile.open("snap")
      t << data.to_json
      t.close
      c(:run_instances, type, "-f", t.path, *args). \
        grep(/INSTANCE/).
        map { |i| from_line(i) }
    end

    def self.terminate(*ids)
      return if ids.length == 0
      c(:terminate_instances, *ids.flatten)
    end

    def self.c(cmd, *args)
      cmd1 = "ec2-#{cmd.to_s.tr('_', '-')} #{args.join(" ")}"
      `#{cmd1}`
    end

    def initialize(fields)
      update(fields)
      yield self if block_given?
    end

    def update(fields)
      case fields
      when Hash
        update_from_hash(fields)
      when Array
        update_from_array(fields)
      when self.class
        update_from_array(fields.to_a)
      else
        fail "Invalid update type '#{fields.class.name}'"
      end
    end

    def update_from_array(a)
      @id,
      @ami_id,
      @public_dns,
      @private_dns,
      @state,
      @key,
      @index,
      @codes,
      @type,
      @raw_created_at,
      @zone = *a

      self
    end

    def update_from_hash(h)
      update_from_array(
        self.class.fields.map {|f| h[f.to_s]}
      )
      self
    end

    def terminate
      c(:terminate_instances, id)
    end

    def c(*args)
      self.class.c(*args)
    end

    def to_a
      [
       id,
       ami_id,
       public_dns,
       private_dns,
       state,
       key,
       index,
       codes,
       type,
       created_at.to_s,
       zone
      ]
    end
    alias :to_ary :to_a

    def to_hash
      self.class.fields.zip(to_a).inject({}) {|m,(k,v)| m[k] = v; m}
    end

    def to_s
      to_a.join("\t")
    end

    def created_at
      @created_at ||= Time.parse(@raw_created_at) rescue nil
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
        sleep(1) until for_what.all? { |what|
          send("#{what}?")
        }
      end
      self
    end

    def active?
      !public_dns.nil? && !public_dns.empty?
    end

    def ssh?
      return true if @ssh == true
      @ssh = begin
               if running?
                 TCPSocket.new(self.public_dns, 22).close
                 true
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

    def terminated?
      self.state == "terminated"
    end

    def console_log
      c(:get_console_output, self.id)
    end

    def reload!
      update(self.class.find(self.id, true))
    end

    def ==(o)
      o.to_hash == self.to_hash
    end

  end

end
