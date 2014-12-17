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
      # protected :actual
      accessor_field :parsed_repo_tag
      #
      class_attribute :max_retries; self.max_retries = 10

      # An image can have multiple tags -- for example, `library/debian:stable` and
      # `library/debian:jessie` are currently identical.
      #
      # @see Rucker::Actual::ActualImage#repo_tags
      # @return [Array[String]] All repo_tag that have the same final layer as this image
      def repo_tags()  actual.try(:repo_tags) || [] ; end

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

      def ours?()     not external? ; end
      def external?() !! external ; end

      def data?()     kind == :data ; end
      def non_data?() not data? ; end

      def readable_size()
        "%4d %2s" % Rucker.bytes_to_human(size) rescue ''
      end


      # Clears any cached information this object might have
      # @return self
      def forget()
        unset_parsed_repo_tag
      end

      #
      # Actions
      #

      def up?()     exists? ; end
      def ready?()  exists? ; end
      def down?()   absent? ; end
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

      # note that a manifest object is not created for the new image, let alone
      # added to the world manifest.
      def add_tag(opts={})
        rt = self.adjusted_name(opts.slice(:reg, :repo, :tag))
        #
        if actual.has_repo_tag?(rt[:repo_tag])
          Rucker.progress(:tagging, self, with: rt[:repo_tag], skipped: "repo_tag #{rt[:repo_tag]} already present")
          return true
        end
        Rucker.progress(:tagging, self, with: rt[:repo_tag])
        actual.tag(repo: rt[:family], tag: rt[:tag])
        true
      end

      def _pull(opts={})
        rt = self.adjusted_name(opts.slice(:reg, :repo, :tag))
        #
        creds = Rucker::Manifest::World.authenticate!(rt[:registry])
        p [rt, creds]
        #
        Rucker.progress(:pulling, self, from: rt[:repo_tag], as: self.repo_tag, note: "This can take a really long time.")
        actual = Rucker::Actual::ActualImage.pull_by_name(
          rt[:registry], rt[:family], rt[:tag], creds[:docker_str],
          &method(:interpret_chunk))
        #
        unless (rt[:repo_tag] == self.repo_tag) || actual.has_repo_tag?(self.repo_tag)
          Rucker.progress(:tagging, rt[:repo_tag], as: self.repo_tag)
          actual.tag(repo: self.family, tag: self.tag)
        end
        forget()
        true
      end

      def push(repo_tag=nil)
        if repo_tag.present?
          name_hsh = Docker.parse_reg_repo_tag(repo_tag)
        else
          name_hsh = self.parsed_repo_tag
        end
        _push(name_hsh.slice(:reg, :repo, :slug, :tag))
      end

      #
      # You can independently override the :reg, :repo, :slug or :tag so
      # that you can bulk push to a different registry; a different account; or
      # with a new versioned tag. (I can't think of why you'd want to bulk-apply
      # the :slug, but you can.
      #
      # Note that {reg: nil} will override the object's registry to mean
      # whereas omitting a key for `:reg` means use the object's registry
      def _push(opts={})
        opts = opts.dup
        rt = self.adjusted_name(opts.extract!(:reg, :repo, :slug, :tag))
        #
        creds = Rucker::Manifest::World.authenticate!(rt[:registry])
        #
        Rucker.progress(:pushing, self, as: rt[:repo_tag], to: rt[:registry], note: "This can take a really long time.")
        actual.push(creds[:docker_str], opts.merge(repo_tag: rt[:repo_tag]), &method(:interpret_chunk))
        #
        forget()
        true
      end

      # Given a hash with :reg, :repo, :slug and :tag, returns a hash with all
      # values of known type and applied defaults:
      #
      # * :repo     the stringified value if present; nil if blank
      # * :slug     the stringified value if present; raises an error if blank
      # * :tag      the stringified value if present, 'latest' if blank
      #
      # If default docker.io registry was implied -- by a reg key that was
      # empty, missing, or contained 'docker.io' within it -- then
      #
      # * :reg       nil
      # * :registry  'index.docker.io'
      # * :family    'repo/slug'
      # * :repo_tag  'repo/slug:tag'
      #
      # Otherwise a registry was named, and the following are set:
      #
      # * :reg      stringified registry name
      # * :registry stringified registry name
      # * :family   'reg/repo/slug'
      # * :repo_tag 'reg/repo/slug:tag'
      #
      # You can supply values for :registry,
      #
      def adjusted_name(in_hsh)
        hsh = in_hsh.
          slice(:reg, :repo, :slug, :tag).
          reverse_merge(self.parsed_repo_tag)
        #
        hsh[:slug] = hsh[:slug].to_s
        raise ArgumentError, "Slug cannot be blank" if hsh[:slug].blank?
        hsh[:repo] = hsh[:repo].present? ? hsh[:repo].to_s : nil
        hsh[:tag] = hsh[:tag].present?   ? hsh[:tag].to_s  : 'latest'
        #
        if (hsh[:reg].blank?) || (/docker.io/ === hsh[:reg])
          hsh[:reg]      = nil
          hsh[:registry] = 'index.docker.io'
          hsh[:family]   = "#{hsh[:repo]}/#{hsh[:slug]}"
        else
          hsh[:reg]      = hsh[:reg].to_s
          hsh[:registry] = hsh[:reg]
          hsh[:family]   = "#{hsh[:reg]}/#{hsh[:repo]}/#{hsh[:slug]}"
        end
        hsh[:repo_tag]   = "#{hsh[:family]}:#{hsh[:tag]}"
        hsh
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

      def _remove
        Rucker.progress(:removing, self)
        actual.untag(self.repo_tag)
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

      def receive_repo_tag(val)
        self.repo_tag = super(val)
      end
      def repo_tag=(val)
        val = "#{val}:latest" unless /:/ === val
        unset_parsed_repo_tag
        @repo_tag = val.to_s
      end

      def repo()     parsed_repo_tag[:repo]   ; end
      def slug()     parsed_repo_tag[:slug]   ; end
      def tag()      parsed_repo_tag[:tag]   || 'latest' ; end
      def family()   parsed_repo_tag[:family] ; end

      #
      def registry() parsed_repo_tag[:reg].blank? ? 'index.docker.io' : parsed_repo_tag[:reg] ; end

      # @see Rucker.repo_tag_order
      # @example images.items.sort_by(&:repo_tag_order)
      def repo_tag_order() Rucker.repo_tag_order(name) ; end

      def to_wire(*)
        super
          .tap{|hsh| hsh.delete(:_type) }
          .merge(:_actual => actual.try(:to_wire))
      end
    end

    class ImageCollection < Rucker::KeyedCollection
      self.item_type = Rucker::Manifest::Image

      def desc
        str = (item_type.try(:type_name) || 'Item')+'s'
        str << ' in ' << belongs_to.desc if belongs_to.respond_to?(:desc)
        str
      end

      #
      # Actions
      #

      def ready(*args)
        return true if ready?
        absentees = select_coll(&:absent?)
        absentees.pull_all
      end

      def state
        map(&:state).uniq.compact
      end
      #
      def ready?() items.all?(&:ready?) ; end
      def clear?() items.all?(&:clear?) ; end


      ::Rucker.module_eval do
        def self.parallelize(coll, operation, num_threads, mutex, opts, &callback)
          mutex.synchronize do
            results = { }
            errors  = { }
            tasks = coll.to_hash.to_a
            img_threads = num_threads.times.map do |worker_idx|
              thr = Thread.new{
                10.times do
                  begin
                    break if tasks.empty?
                    break if errors.present? && (not opts[:ignore_failure])
                    key, img = tasks.pop
                    results[key] = callback.call(key, img)
                    Rucker.progress(operation, "worker_#{worker_idx}", finished: key, with: results[key], remaining: tasks.length)
                  rescue StandardError => err
                    Rucker.progress(operation, img, error: err.message)
                    errors[key] = err
                  end
                end
              }
            end
            img_threads.each_with_index do |thr, idx|
              thr.join
              Rucker.progress(operation, "worker_#{idx}", finished: "running #{operation}")
            end
            if errors.present? && (not opts[:ignore_failure])
              err = Rucker::Error::ParallelError.with_errors(errors)
              raise err
            end
            [results, errors]
          end
        end
      end

      @@push_pull_mutex ||= Mutex.new

      def pull_all(opts={})
        Rucker.parallelize(self, :pull, 3, @@push_pull_mutex, opts) do |key, img|
          img._pull(opts)
          img.refresh!
        end
      end

      def push_all(opts={})
        imgs_to_push = select_coll(&:ours?)
        Rucker.parallelize(imgs_to_push, :push, 3, @@push_pull_mutex, opts) do |key, img|
          img._push(opts)
        end
      end

      #
      # Slicing
      #

      # collection of images with given family, sorted by value
      # @see
      def select_coll(&blk)
        coll = new_empty_collection
        clxn.values.
          sort_by(&:repo_tag_order).
          each{|item| coll.add(item) if yield(item) }
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
              img.send(:actual=, actual.dup) if img.repo_tag == rt
            end
          end
        end
        #
        self
      end

    end

  end
end
