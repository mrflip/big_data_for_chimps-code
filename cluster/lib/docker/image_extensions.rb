module Docker
  #
  # We're not breaking caching rules here, just adding sugar
  #
  Image.class_eval do

    def untagged?()  names == ["<none>:<none>"] ; end

    def names()      info['RepoTags'] ; end

    def created_at() info['Created']            ; end

    def size()       info['VirtualSize']        ; end

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

    # def parent_id()  info['ParentId'] ; end
    # def layer_size() info['Size'] ; end

    # def refresh_images!
    #   receive_images(fetch_raw_images)
    # end
    #
    # def fetch_raw_images
    #   docker_objs = Docker::Image.all
    #   image_manifests = manifest.images
    #   docker_objs.map do |docker_obj|
    #     info = docker_obj.info
    #     .map do |tagged_name|
    #       next if tagged_name == '<none>:<none>' # all of ours are tagged
    #       image_manifest = image_manifests[tagged_name]
    #       next unless image_manifest.present?
    #       raw_image = {
    #         name:       tagged_name,
    #         id:         info['id'],
    #         created_at: info['Created'],
    #         size:       info['VirtualSize'],
    #         manifest:   image_manifest,
    #         docker_obj: docker_obj,
    #       }
    #     end
    #   end.flatten.compact
    # end
  end
end
