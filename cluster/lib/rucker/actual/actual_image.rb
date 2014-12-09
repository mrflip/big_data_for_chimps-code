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
        repo_tags.include?([repo_tag, tag].compact.join(':')) rescue false
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

      def self.pull_by_name(registry, image_name, tag, docker_creds, &callback)
        create({'registry' => registry, 'fromImage' => image_name, 'tag' => tag},
          docker_creds, &callback)
      end

      # Remove the Image from the server.
      def untag(repo_tag, opts = {})
        connection.delete("/images/#{repo_tag}", opts)
      end

    end
  end
end
