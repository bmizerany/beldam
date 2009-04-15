module EC2

  class Instance
    include Common

    fields "id", "ami_id", "public_dns", "private_dns",
      "state", "key", "index", "codes", "type",
      "created_at", "zone"

    selector :describe_instances,
      :identification_regex => /INSTANCE/

    def self.create(image_ids, options={}, data={})
      opts = OptionParser.new do |defaults|
        unless data.empty?
          t = Tempfile.open("beldam")
          t << data.to_json
          t.close
          defaults[:f] = t.path
        end
        defaults[:z] = "us-east-1a"
      end

      c(:run_instances, *(Array(image_ids) + opts.parse(options))).
        split("\n").
        grep(/INSTANCE/).
        map {|i| from_line(i)}
    end

    def self.destroy(*ids)
      return if ids.length == 0
      c(:terminate_instances, *ids.flatten)
    end

    def destroy
      self.class.destroy(id)
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

    def reload!
      update(self.class.find(id, true))
    end

    def active?
      !public_dns.nil? && !public_dns.empty?
    end

    def ssh?
      begin
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
