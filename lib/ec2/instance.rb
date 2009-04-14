module EC2

  class Instance
    include Common

    fields "id", "ami_id", "public_dns", "private_dns",
      "state", "key", "index", "codes", "type",
      "created_at", "zone"

    selector :describe_instances,
      :identification_regex => /INSTANCE/

    def self.run(image_ids, options={}, data={})
      unless data.empty?
        t = Tempfile.open("beldam")
        t << data.to_json
        t.close
        options[:f] ||= t.path
      end

      options[:z] ||= "us-east-1a"

      args = options.inject([]) {|m,(k,v)|
        option = k.to_s.size > 1 ? "--#{k}" : "-#{k}"
        m << option << v
      }

      c(:run_instances, *(Array(image_ids) + args)).
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
