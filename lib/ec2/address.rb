module EC2

  class Address
    include Common

    fields "id", "instance_id"

    alias :ip :id

    selector :describe_addresses

    def self.create(options={})
      opts = OptionParser.new

      returnify(
        c(:allocate_address, *opts.parse(options)).
          split("\n").
          grep(/ADDRESS/).
          map {|i| from_line(i)}
      )
    end

    def associate(instance)
      fail "Instance #{instance.id} is not running" unless instance.running?
      fail "Address #{ip} already associated" if associated?
      update(c(:associate_address, self.ip, "-i", instance.id))
    end

    def disassociate
      update(c(:disassociate_address, self.ip))
    end

    def associated?
      !instance_id.to_s.empty?
    end

  end

end
