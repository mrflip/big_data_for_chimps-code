module Rucker
  module Manifest
    class Image < Rucker::Manifest::Base
      field :name,        :string,  doc: "Full name -- ns/slug:tag -- for image"
      field :external,    :boolean, doc: 'Is this one of your images, i.e. it should be included in a push or build?'
      field :kind,        :symbol,  doc: ':data for containers-used-as-volumes'
      field :est_size,    :string,  doc: 'An advisory statement of the actual image size.'
      #
      accessor_field :actual, Rucker::Actual::ActualImage
      protected :actual
      #
      class_attribute :max_retries; self.max_retries = 10

      # An image can have multiple tags -- for example, `library/debian:stable` and
      # `library/debian:jessie` are currently identical.
      #
      # @see Rucker::Actual::ActualImage#names
      # @return [Array[String]] All tags that apply to this image
      def names()      actual.try(:names) ; end

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

      def readable_size()
        "%4d %2s" % Rucker.bytes_to_human(size) rescue ''
      end


      # Clears any cached information this object might have
      # @return self
      def forget()
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

      def _pull
        Rucker.progress("  Pulling ", :brc, desc, ". This can take a really long time.")
        actual = Rucker::Actual::ActualImage.pull_using_manifest(self)
        forget()
        self
      end

      def pull(*args) _pull(*args)  end

      def push
        Rucker.progress("  Pushing ", :brc, desc, ". This can take a really long time.")
        Rucker::Actual::ActualImage.push_using_manifest(self)
        forget()
        self
      end

      def _remove
        Rucker.progress(:brr, "  Removing ", :brc, desc, ". Hope you meant to do so.")
        actual.remove_using_manifest(self)
        forget()
        self.actual = nil
        self
      end

      #
      # State Handling
      #

      def refresh!
        forget()
        if not self.actual.present?
          self.actual = Rucker::Actual::ActualImage.get(name)
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
            Rucker.progress("#{operation} -> single #{desc} (#{state_desc}) #{idx > 1 ? " (#{idx})" : ''}")
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
      # Name handling
      #

      def parsed_name
        @parsed_name ||= self.class.split_name(name)
      end

      def ns()     @ns     ||= parsed_name[:ns]     ; end
      def slug()   @slug   ||= parsed_name[:slug]   ; end
      def tag()    @tag    ||= parsed_name[:tag]    ; end
      def family() @family ||= parsed_name[:family] ; end
      def namespace() ns() ;  end

      # note: tag versions are derp-sorted: 10.2 precedes 2.0
      def comparable_name()
        [ ns.to_s, slug.to_s, (tag == 'latest' ? '' : tag.to_s) ]
      end

      IMAGE_NAME_RE = %r{\A
      (                                       # family (ns/slug)
        (?:   ([a-z0-9_]{1,30})       / )?    # ns /    ( a-z 0-9 _     ) optional, omit the /
              ([a-z0-9_\.\-]+|<none>)      )  # slug    ( a-z 0-9 - . _ )
        (?: : ([a-z0-9_\.\-]+|<none>)   )?    # : tag,  ( a-z 0-9 - . _ ) optional, omit the /
      \z}x
      def self.split_name(name)
        name.match(IMAGE_NAME_RE) or raise("Bad match")
        { name: name, ns: $2, slug: $3, tag: $4, family: $1 }
      rescue StandardError => err
        Rucker.warn "Couldn't parse name #{name}: #{err}"
        { name: name, ns: nil, slug: "<unknown: #{name}>", tag: nil, family: "<unknown: #{name}>" }
      end

      def self.normalize_name(name)
        parsed = split_name(name)
        [parsed[:family] , ':', (parsed[:tag]||'latest') ].join
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

      #
      # Slicing
      #

      # collection of images with given family, sorted by tag (with tag 'latest' first)
      def with_family(family)
        coll = new_empty_collection
        clxn.
          find_all{|key, item| item.family.to_s == family.to_s }.
          sort_by(&:comparable_name).
          each{|item| coll.add(item) }
        coll
      end

      #
      # State
      #

      def refresh!
        # Reset all the images
        each{|img| img.forget ; img.remove_instance_variable(:@actual) if img.instance_variable_defined?(:@actual) }
        # Collect the names of the manifest images
        img_names = keys.map(&:to_s).to_set
        #
        # Gift the actual image to each manifest that refers to it.
        Rucker::Actual::ActualImage.all().map do |actual|
          next if actual.untagged?
          img_names.intersection(actual.names).each do |name|
            self[name].actual = actual
          end
        end
        #
        self
      end

    end

  end
end
