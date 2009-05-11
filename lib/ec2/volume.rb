module EC2

  class Volume
    include Common

    fields "id", "size", "snapshot", "zone",
      "state", "created_at"

    selector :describe_volumes

    def self.create(options={})
      opts = OptionParser.new(:z => "us-east-1a")

      returnify(
        c(:create_volume, opts.parse(options)).
        split("\n").
        grep(/VOLUME/).
        map {|i| from_line(i)}
      )
    end

    def self.destroy_all
      all.each {|v| v.destroy if v.available?}
    end

    def attach(instance, device="/dev/sdh")
      c(:attach_volume, self.id, "-i", instance.id, "-d", device).
        split("\n").
        grep(/ATTACHMENT/).
        map {|l| Attachment.from_line(l)}.
        first
    end

    def detach
      Attachment.new(c(:detach_volume, self.id))
    end

    def destroy
      unless available?
        fail "Volume not available for destroy #{self.id}"
      end
      c(:delete_volume, self.id)
      self.tap {|i| i.state = "terminated"}
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

    def terminated?
      self.state == "terminated"
    end

  end

end
