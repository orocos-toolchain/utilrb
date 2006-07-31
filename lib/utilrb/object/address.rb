
class Object
    # Return the object address (for non immediate
    # objects). 
    def address; Object.address_from_id(object_id) end

    # Converts the object_id of a non-immediate object
    # to its 32 bits address
    def self.address_from_id(id)
	id = 0xFFFFFFFF - ~id if id < 0
	(id * 2) & 0xFFFFFFFF
    end
end

