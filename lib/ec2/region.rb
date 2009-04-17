module EC2

  class Region
    include Common

    fields "id", "endpoint"
    selector :describe_regions
  end

end
