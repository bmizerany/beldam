module EC2

  class Volume
    include Common

    fields "id", "size", "snapshot", "zone",
      "state", "created_at"

    selector :describe_volumes,
      :identification_regex => /VOLUME/

    def self.create(options={})
      opts = OptionParser.new(:z => "us-east-1a")

      c(:create_volume, opts.parse(options)).
        split("\n").
        grep(/VOLUME/).
        map {|i| from_line(i)}
    end

    def attach(instance, device="/dev/sdh")
      c(:attach_volume, self.id, "-i", instance.id, "-d", device)
    end

    def detach
      c(:detach_volume, self.id)
    end

    def destroy
      unless available?
        fail "Volume not available for destroy #{self.id}"
      end
      c(:delete_volume, self.id)
    end

    def wait!(*for_what)
      Timeout.timeout(60) do
        sleep(1) && reload! until for_what.all? { |what|
          send("#{what}?")
        }
      end
      self
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
