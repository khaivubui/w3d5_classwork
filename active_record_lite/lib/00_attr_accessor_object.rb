class AttrAccessorObject
  def self.my_attr_accessor(*names)
    names.each do |instance_variable|
      define_method(instance_variable) do
        self.instance_variable_get("@#{instance_variable}")
      end

      define_method("#{instance_variable}=") do |value|
        self.instance_variable_set("@#{instance_variable}", value)
      end
    end
  end
end
