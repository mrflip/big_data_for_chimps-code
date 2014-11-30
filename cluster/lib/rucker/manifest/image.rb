# -*- coding: utf-8 -*-
module Rucker
  module Manifest
    class Image < Rucker::Manifest::Base
      field :name,        :string,  doc: "Symbolic name for this image. *Not* the reg/repo/slug:tag."
      field :repo_tag,    :string,  doc: "Full name -- reg/repo/slug:tag -- for image. Registry and Tag optional"
      field :external,    :boolean, doc: 'Is this one of your images, i.e. it should be included in a push or build?'
      field :kind,        :symbol,  doc: 'should have the value :data, for containers-used-as-volumes'
      field :est_size,    :string,  doc: 'An advisory statement of the actual image size.'
      #
      accessor_field :actual, Rucker::Actual::ActualImage, writer: true
      protected :actual
      accessor_field :parsed_repo_tag
      #
      class_attribute :max_retries; self.max_retries = 10

      # An image can have multiple tags -- for example, `library/debian:stable` and
      # `library/debian:jessie` are currently identical.
      #
      # @see Rucker::Actual::ActualImage#repo_tags
      # @return [Array[String]] All repo_tag names that apply to this image
      def aliases()      actual.try(:repo_tags) || [] ; end

      # @see Rucker::Actual::ActualImage#id
      # @return [String] ID for this image as a long hexadecimal string
      def id()         actual.try(:id) || ''  ; end
      # @return [String] ID for this image as a 13-character hexadecimal string
      def short_id()   id[0..12]              ; end

      # @see Rucker::Actual::ActualImage#created_at
      # @return [Time] Creation time of this image
      def created_at() actual.try(:created_at) ; end

      # @see Rucker::Actual::ActualImage#size
      # @return [Integer] Size of all layers that comprise this image
      def size()       actual.try(:size) ; end

      def ours?() not external? ; end

      def external?() !! external ; end

      def readable_size()
        "%4d %2s" % Rucker.bytes_to_human(size) rescue ''
      end


      # Clears any cached information this object might have
      # @return self
      def forget()
        unset_parsed_repo_tag
        self
      end

      #
      # Actions
      #

      def ready?()  exists? ; end
      def clear?()  absent? ; end

      def exists?() state == :exists ; end
      def absent?() state == :absent ; end

      def ready(*args) invoke_until_satisfied(:ready, *args) ; end
      def clear(*args) invoke_until_satisfied(:clear, *args) ; end

      def _ready
        case state
        when :exists  then            return true
        when :absent  then _pull    ; return false # wait for pull
        else                          return false # don't know, hope we figure it out.
        end
      end

      def _clear
        case state
        when :exists  then _remove  ; return false # wait for remove
        when :absent  then          ; return true
        else                          return false # don't know, hope we figure it out.
        end
      end

      def _pull(registry, opts={})
        Rucker.progress(:pulling, self, note: "This can take a really long time.")
        creds_hsh = Rucker::Manifest::World.authenticate!(registry)
        #
        actual = Rucker::Actual::ActualImage.pull_using_manifest(self)
        forget()
        true
      end

      def _push(registry, opts={})
        Rucker.progress(:pushing, self, note: "This can take a really long time.")
        creds_hsh = Rucker::Manifest::World.authenticate!(registry)
        #
        push_repo_tag = creds_hsh
        actual.push(Docker.creds, opts, &method(:interpret_chunk))
        #
        forget()
        true
      end

      PROGRESS_BAR_RE = %r{\[([^\]])\] ([\d\.]+) (\w\w)/([\d\.]+) (\w\w) (\w+)}
      PROGRESS_MUTING = 0.1

      def interpret_chunk(step)
        case step['status']
        when /^(Pushing|Pulling) repository ([^\s]+)(?: \((\d+) tags\))?/
          Rucker.progress(($1.downcase.to_sym), self, as: $2)
        when /^Pulling image \((.*)\) from (.*)/
          Rucker.progress(:downloading, self, layer: step['id'], from: $2)
        when /Sending image list/
          Rucker.progress(:preparing, self, as: 'list of layers')
        when /^(Pushing|Downloading)\z/
          if step['progress'] && (rand < PROGRESS_MUTING)
            Rucker.progress(:bored_now, self, progress: step['progress'])
          end
        when /^Buffering|The push refers to a repository|Pulling metadata|Pulling fs layer|Pulling dependent layers/
          # pass
        when /^Image ([^ ]*) ?already pushed, skipping/
          Rucker.progress(:sending, self, layer: $1 || step['id'], skipped: 'layer already pushed')
        when /^Image successfully pushed/
          Rucker.progress(:sent,    self, layer: step['id'])
        when /^Download complete/
          Rucker.progress(:downloaded, self, layer: step['id'])
        when /^Pushing tag for rev \[([^\]]+)\] on \{([^\}]+)/
          Rucker.progress(:tagged,  self, layer: $1, as: $2)
        when /^Status: (Downloaded newer image|Image is up to date) for (.+)/
          Rucker.progress(:pulled,  self)
        else
          Rucker.progress(:in_pushing, self, step: step.inspect)
        end
      end

      # note that a manifest object is not created for the new image, and
      # nothing is added to the world.
      def add_repo_tag(new_repo_tag)
        if actual.has_repo_tag?(new_repo_tag)
          Rucker.progress(:tagging, self, with: new_repo_tag, skipped: "tag #{new_repo_tag} already present")
          return true
        end
        new_family, new_tag = new_repo_tag.split(/:/, 2)
        Rucker.progress(:tagging, self, with: "#{new_family}:#{new_tag}")
        actual.tag(repo: new_family, tag: new_tag)
        true
      end

      def _remove
        Rucker.progress(:removing, self)
        actual.remove_using_manifest(self)
        forget()
        self.actual = nil
        true
      end

      #
      # State Handling
      #

      def refresh!
        forget()
        if self.actual.present?
          self.actual.refresh!
        else
          self.actual = Rucker::Actual::ActualImage.get(repo_tag)
        end
        self
      rescue Docker::Error::NotFoundError => err
        self.actual = nil
        self
      end

      def state
        case
        when actual.blank? then :absent
        else                    :exists
        end
      end

      def state_desc
        states = Array.wrap(state)
        case
        when states == []       then "missing anything to report state of"
        when states.length == 1 then states.first.to_s
        else
          fin = states.pop
          "a mixture of #{states.join(', ')} and #{fin} states"
        end
      end

      def invoke_until_satisfied(operation, *args)
        forget
        max_retries.times do |idx|
          begin
            Rucker.output("#{operation} -> single #{desc} (#{state_desc}) #{idx > 1 ? " (#{idx})" : ''}")
            success = self.public_send("_#{operation}", *args)
            return true if success
          rescue Docker::Error::NotFoundError => err
            Rucker.warn "Missing image in #{operation} -> #{name}: #{err}; skipping"
            refresh!
            return false
          rescue Docker::Error::DockerError => err
            Rucker.warn "Problem with #{operation} -> #{name}: #{err}"
            sleep 2
          end
          refresh!
        end
        Rucker.die "Could not bring #{self.inspect_compact} to #{operation} after #{max_retries} attempts. Dying."
      end

      #
      # Repo_Tag handling
      #

      def parsed_repo_tag
        @parsed_repo_tag ||= Docker::Util.parse_reg_repo_tag(repo_tag)
      end

      def repo()     parsed_repo_tag[:repo]   ; end
      def slug()     parsed_repo_tag[:slug]   ; end
      def tag()      parsed_repo_tag[:tag]    ; end
      def family()   parsed_repo_tag[:family] ; end
      def path()     parsed_repo_tag[:path]   ; end


      # @see #registry if you want to know where to eg invoke credentials
      def reg()      parsed_repo_tag[:reg]    || self.class.default_registry ; end

      # As far as I can tell, the only way to specify the docker.io registry is
      # to specify no registry, and the empty registry is always
      # 'index.docker.io'. Ugh.
      def registry()
        reg.present? ? reg : 'index.docker.io'
      end

      # @see Rucker.repo_tag_order
      # @example images.items.sort_by(&:repo_tag_order)
      def repo_tag_order() Rucker.repo_tag_order(name) ; end

      def self.normalize_repo_tag(repo_tag)
        parsed = Docker::Util.parse_reg_repo_tag(repo_tag)
        reg  = (parsed[:registry] || default_registry)
        repo = (parsed[:repo]     || default_repo)
        tag  = (parsed[:tag]      || default_tag)
        [reg, '/', rep, parsed[:slug], ':', tag ].join
      end

      def to_wire(*)
        super
          .tap{|hsh| hsh.delete(:_type) }
          .merge(:_actual => actual.try(:to_wire))
      end
    end

    class ImageCollection < Rucker::KeyedCollection
      self.item_type = Rucker::Manifest::Image

      #
      # Actions
      #

      def ready(*args) map{|item| item.ready }.all? ; end
      def clear(*args) map{|item| item.clear }.all? ; end

      def push
        results = { }
        img_threads = clxn.map do |key, img|
          Thread.new{
            results[key] = img._push
          }
        end
        img_threads.each{|thr| thr.join }
        results
      end

      #
      # Slicing
      #

      # collection of images with given family, sorted by tag (with tag 'latest' first)
      def select_coll(&blk)
        coll = new_empty_collection
        clxn.each_value{|item| coll.add(item) if yield(item) }
        coll
      end

      #
      # State
      #

      def refresh!
        # Reset all the images
        each{|img| img.forget ; img.unset_actual }
        # Gift the actual image to each manifest that refers to it.
        Rucker::Actual::ActualImage.all().map do |actual|
          next if actual.untagged?
          actual.repo_tags.each do |rt|
            items.each do |img|
              # dup, because two handles might point to same repo_tag.
              img.actual = actual.dup if img.repo_tag == rt
            end
          end
        end
        #
        self
      end

    end

  end
end
