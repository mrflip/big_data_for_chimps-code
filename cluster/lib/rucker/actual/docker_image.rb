# -*- coding: utf-8 -*-
module Rucker
  module Actual
    #
    # We're not breaking caching rules here, just adding sugar
    #
    class DockerImage < ::Docker::Image

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

      # ===========================================================================
      #
      # State
      #

      def state()
        :created
      end

      def created?()    state == :created ; end
      def transition?() false             ; end
      def absent?()     false             ; end
      def exists?()     not absent?       ; end

      def up?()         exists?           ; end
      def ready?()      exists?           ; end
      def down?()       true              ; end
      def clear?()      absent?           ; end

      # ===========================================================================
      #
      # Actions
      #

      def self.pull_by_name(registry, image_name, tag, docker_creds, &callback)
        create({'registry' => registry, 'fromImage' => image_name, 'tag' => tag},
          docker_creds, &callback)
      end

      # Remove the Image from the server.
      def untag(repo_tag, opts = {})
        connection.delete("/images/#{repo_tag}", opts)
      end

      PROGRESS_BAR_RE = %r{\[([^\]])\] ([\d\.]+) (\w\w)/([\d\.]+) (\w\w) (\w+)}
      PROGRESS_MUTING = 0.1

      def interpret_chunk(step, actual)
        case step['status']
        when /^(Pushing|Pulling) repository ([^\s]+)(?: \((\d+) tags\))?/
          Rucker.progress(($1.downcase.to_sym), self, from: $2)
        when /^Pulling image \((.*)\) from (.*)/
          Rucker.progress(:downloading, self, layer: step['id'], from: $2)
        when /Sending image list/
          Rucker.progress(:preparing, self, as: 'list of layers')
        when /^(Pushing|Downloading)\z/
          if step['progress']
            Rucker.progress(:bored_now, self, progress: step['progress'], mute: PROGRESS_MUTING)
          end
        when /^Buffering|The push refers to a repository|Pulling metadata|Pulling fs layer|Pulling dependent layers/
          # pass
        when /^Extracting|The image you are pulling has been verified/
          # pass
        when /^Image (?:([^ ]+) )?already pushed, skipping/
          Rucker.progress(:sending, self, layer: step['id'] || $1 || step.to_s,
            skipped: 'layer already pushed', mute: 0.1)
        when /^Already exists/
          Rucker.progress(:downloaded, self, layer: step['id'] || step.to_s,
            skipped: 'layer already exists', mute: 1.0)
        when /^Image successfully pushed/
          Rucker.progress(:sent,    self, layer: step['id'])
        when /^(Download|Pull) complete/
          Rucker.progress(("#{$1}ed".downcase.to_sym), self, layer: step['id'])
        when /^Pushing tag for rev \[([^\]]+)\] on \{([^\}]+)/
          Rucker.progress(:tagged,  self, layer: $1, as: $2)
        when /^Status: (Downloaded newer image|Image is up to date) for (.+)/
          Rucker.progress(:pulled,  self)
        else
          Rucker.progress(:unknown, self, step: step.inspect)
        end
      end


    end
  end
end
