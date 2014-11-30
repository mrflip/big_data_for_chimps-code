# -*- coding: utf-8 -*-
module Rucker
  module Actual
    #
    # We're not breaking caching rules here, just adding sugar
    #
    class ActualImage < Docker::Image

      #
      def untagged?()  repo_tags == ["<none>:<none>"] ; end

      # An image can have multiple tags -- for example, `library/debian:stable`
      # and `library/debian:jessie` are currently identical, and so might
      # `your/hadoop_nn`, `bd4c/hadoop_nn` & `your.registry.com/your/hadoop_nn`
      #
      # @return [Array[String]] All tags that apply to this image
      def repo_tags()      info['RepoTags'] ; end

      # @return [String] ID for this image as a 13-character hexadecimal string
      def short_id()   id[0..12]              ; end

      def desc
        "#{self.class.name.demodulize} #{short_id}"
      end

      def has_repo_tag?(repo_tag, tag=nil)
        repo_tag = [repo_tag, tag].compact.join(':')
        unless (%r{:} === repo_tag) then warn "has_repo_tag? should be called with a fully-qualified repo_tag (eg foo/bar:baz) or nothing will match" ; end
        repo_tags.include?(repo_tag.to_s)
      end

      # @return [Time] Creation time of this image
      def created_at()
        Time.at( info['Created'] ).utc.iso8601 rescue nil
      end

      # @return [Integer] Size of all layers that comprise this image
      def size()       info['VirtualSize']        ; end

      # @return [Integer] Size of the last layer in this image
      def layer_size() info['Size'] ; end

      # @return [String] Image ID for the prior build step of this image
      def parent_id()  info['ParentId'] ; end

      def to_wire(*)
        { repo_tags: repo_tags, size: size, id: id, created_at: created_at }
      end

      def self.pull_using_manifest(img)
        create('id'   => img.repo_tag,  'repo' => img.repo,
          'fromImage' => img.path,  'tag'  => img.tag,
          'registry'  => img.reg,
          &img.method(:interpret_chunk))
      end

      def remove_using_manifest(img)
        untag(img.repo_tag)
      end

      # Remove the Image from the server.
      def untag(repo_tag, opts = {})
        connection.delete("/images/#{repo_tag}", opts)
      end

      # # Push the Image to the Docker registry.
      # def push_to(registry, ns, slug, tag_name, credentials, options = {})
      #   if registry =~ /index\.docker\.io/
      #     pushed_name = "#{ns}/#{slug}"
      #   else
      #     pushed_name = "#{registry}/#{ns}/#{slug}"
      #   end
      #   tag(repo: pushed_name, tag: tag_name)
      #   #
      #   headers = Docker::Util.build_auth_header(credentials)
      #   opts = {:tag => tag_name}.merge(options)
      #   p [registry, pushed_name, tag_name, credentials, opts]
      #   callback = opts.delete(:response_block)
      #   connection.post("/images/#{pushed_name}/push", opts, :headers => headers, &callback)
      #   self
      # end

      #
      # These are brought over from Docker::Image so that they behave as
      # proper subclasses.
      #

      # # Create a new Image.
      # def self.create(query = {}, creds = nil, conn = Docker.connection)
      #   credentials = creds.nil? ? Docker.creds : creds.to_json
      #   headers = !credentials.nil? && Docker::Util.build_auth_header(credentials)
      #   headers ||= {}
      #   caller_resp_blk = query.delete(:response_block)
      #   new_id = nil
      #   resp_blk = lambda do |chunk, *_|
      #     step = MultiJson.decode(chunk)
      #     if    step['error'] && (%r{not found in repository} === step['error'])
      #       raise Docker::Error::NotFoundError, step['error']
      #     elsif step['error']
      #       raise Docker::Error::ServerError,   step['error']
      #     end
      #     new_id = step['id'] if step['id']
      #     # TODO: what should we do with errors here?
      #     caller_resp_blk.call(step) if caller_resp_blk
      #   end
      #   #
      #   body = conn.post('/images/create', query, :headers => headers, :response_block => resp_blk)
      #   new(conn, 'id' => new_id, :headers => headers)
      # end

      # # Return a String representation of the Image.
      # def to_s
      #   "#{self.class.name} { :id => #{self.id}, :info => #{self.info.inspect}, "\
      #   ":connection => #{self.connection} }"
      # end
      # 
      # 
      # # Update the @info hash, which is the only mutable state in this object.
      # def refresh!
      #   img = self.class.all(:all => true).find { |image|
      #     image.id.start_with?(self.id) || self.id.start_with?(image.id)
      #   }
      #   info.merge!(self.json)
      #   img && info.merge!(img.info)
      #   self
      # end


    end
  end
end
