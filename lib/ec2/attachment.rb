module EC2

  class Attachment
    include Common

    fields "id", "instance_id", "device", "state", "created_at"

    selector :describe_volumes, :identification_regex => /ATTACHMENT/

    def detach
      volume.detach
    end

    def volume
      Volume.all.find {|v| v.id == self.id}
    end

  end

end
