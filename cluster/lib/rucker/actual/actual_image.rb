module Rucker
  module Actual
    #
    # We're not breaking caching rules here, just adding sugar
    #
    class ActualImage < Docker::Image

      # 
      def untagged?()  names == ["<none>:<none>"] ; end

      # An image can have multiple tags -- for example, `library/debian:stable` and
      # `library/debian:jessie` are currently identical.
      #
      # @return [Array[String]] All tags that apply to this image
      def names()      info['RepoTags'] ; end

      # @return [Time] Creation time of this image
      def created_at() info['Created']            ; end

      # @return [Integer] Size of all layers that comprise this image
      def size()       info['VirtualSize']        ; end

      # @return [Integer] Size of the last layer in this image
      def layer_size() info['Size'] ; end

      # @return [String] Image ID for the prior build step of this image
      def parent_id()  info['ParentId'] ; end

      def to_wire(*)
        { names: names, size: size, id: id, created_at: created_at }
      end

      
      def self.pull_using_manifest(img)
        create('id' => img.name, 'repo' => img.ns, 'fromImage' => img.family, 'tag' => img.tag)
      end

      def remove_using_manifest(img)
        untag(img.name)
      end

      # Remove the Image from the server.
      def untag(name, opts = {})
        connection.delete("/images/#{name}", opts)
      end

      # Create a new Image.
      def self.create(opts = {}, creds = nil, conn = Docker.connection)
        credentials = creds.nil? ? Docker.creds : creds.to_json
        headers = !credentials.nil? && Docker::Util.build_auth_header(credentials)
        headers ||= {}
        body = conn.post('/images/create', opts, :headers => headers)
        fixed_body = Docker::Util.fix_json(body)
        fixed_body.select{|m| m['error'] }.each do |m|
          # p [ m['error'], %r{not found in repository} === m['error']  ]
          if %r{not found in repository} === m['error']
            raise Docker::Error::NotFoundError, m['error']
          else
            raise Docker::Error::ServerError,   m['error']
          end
        end
        id = fixed_body.select { |m| m['id'] }.last['id']
        new(conn, 'id' => id, :headers => headers)
      end

      #
      # These are brought over from Docker::Image so that they behave as
      # proper subclasses.
      #

      # Return a String representation of the Image.
      def to_s
        "#{self.class.name} { :id => #{self.id}, :info => #{self.info.inspect}, "\
        ":connection => #{self.connection} }"
      end

      
      # Update the @info hash, which is the only mutable state in this object.
      def refresh!
        img = self.class.all(:all => true).find { |image|
          image.id.start_with?(self.id) || self.id.start_with?(image.id)
        }
        info.merge!(self.json)
        img && info.merge!(img.info)
        self
      end

      
    end
  end
end
