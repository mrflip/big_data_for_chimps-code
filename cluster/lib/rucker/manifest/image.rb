module Rucker
  class Image < Rucker::Manifest::Base
    field :name,        :string,  doc: "Full name -- ns/slug:tag -- for image"
    field :external,    :boolean, doc: 'Is this one of your images, i.e. it should be included in a push or build?'
    field :kind,        :symbol,  doc: ':data for containers-used-as-volumes'
    #
    attr_accessor :docker_obj
    class_attribute :max_retries; self.max_retries = 10

    def names()      docker_obj.try(:names) ; end

    def id()         docker_obj.try(:id)    ; end
    def short_id()   id[0..12]              ; end

    def created_at() docker_obj.try(:created_at) ; end

    def size()       docker_obj.try(:size) ; end

    def forget()
      self
    end

    def refresh!
      forget()
      if not self.docker_obj.present?
        self.docker_obj = Docker::Image.get(name)
      end
      self
    rescue Docker::Error::NotFoundError => err
      self.docker_obj = nil
      self
    end

    def state
      case
      when docker_obj.blank? then :absent
      else                        :exists
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
          warn "Problem with #{operation} -> #{name}: #{err}; skipping"
          refresh!
          return false
        rescue Docker::Error::DockerError => err
          warn "Problem with #{operation} -> #{name}: #{err}"
          sleep 2
        end
        refresh!
      end
      Rucker.die "Could not bring #{self.inspect_compact} to #{operation} after #{max_retries} attempts. Dying."
    end


    def ready?()  exists? ; end
    def clear?()  absent? ; end
    def exists?() state == :exists ; end
    def absent?() state == :absent ; end


    def ready(*args) invoke_until_satisfied(:ready, *args) ; end
    def clear(*args) invoke_until_satisfied(:clear, *args) ; end

    def push
      Rucker.progress("  Pushing #{desc}. This can take a really long time.")
      Docker::Image.push_using_manifest(self)
      forget()
      self
    end

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
      Rucker.progress("  Pulling #{desc}. This can take a really long time.")
      docker_obj = Docker::Image.pull_using_manifest(self)
      forget()
      self
    end

    def _remove
      Rucker.progress("  Removing #{desc}. Hope you meant to do so.")
      docker_obj.remove_using_manifest(self)
      forget()
      self.docker_obj = nil
      self
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


    # note: tag versions are derp-sorted: 10.2 precedes 2.0
    def comparable_name()
      [ ns.to_s, slug.to_s, (tag == 'latest' ? '' : tag.to_s) ]
    end

    IMAGE_NAME_RE = %r{\A
      (                                     # family (ns/slug)
        (?:   ([a-z0-9_]{1,30})       / )?    # ns /    ( a-z 0-9 _     ) optional, omit the /
              ([a-z0-9_\.\-]+|<none>)      )  # slug    ( a-z 0-9 - . _ )
        (?: : ([a-z0-9_\.\-]+|<none>)   )?    # : tag,  ( a-z 0-9 - . _ ) optional, omit the /
      \z}x
    def self.split_name(name)
      name.match(IMAGE_NAME_RE) or raise("Bad match")
      { name: name, ns: $2, slug: $3, tag: $4, family: $1 }
    rescue StandardError => err
      warn "Couldn't parse name #{name}: #{err}"
      { name: name, ns: nil, slug: "<unknown: #{name}>", tag: nil, family: "<unknown: #{name}>" }
    end

    def self.normalize_name(name)
      parsed = split_name(name)
      [parsed[:family] , ':', (parsed[:tag]||'latest') ].join
    end

    #
    # Machinery
    #

    # used by KeyedCollection to know how to index these
    def collection_key()        name ; end
    # used by KeyedCollection to know how to index these
    def set_collection_key(key) receive_name(key) ; end

    # Allows :docker_obj to be passed in as a receive attr even though it's not a field.
    def handle_extra_attributes(attrs)
      @docker_obj = attrs.delete(:docker_obj) if attrs.include?(:docker_obj)
      super(attrs)
    end
  end


  class ImageCollection < KeyedCollection
    # collection of images with given family, sorted with 'latest' at front.
    def with_family(family)
      coll = new_empty_collection
      clxn.
        find_all{|key, item| item.family.to_s == family.to_s }.
        sort_by(&:comparable_name).
        each{|item| coll.add(item) }
      coll
    end

    def ready(*args) map{|item| item.ready }.all? ; end
    def clear(*args) map{|item| item.clear }.all? ; end

    def refresh!
      # Reset all the containers and get a lookup table of containers
      each{|img| img.forget ; img.remove_instance_variable(:@docker_obj) if img.instance_variable_defined?(:@docker_obj) }
      #
      # Grab all the containers
      #
      img_names = keys.map(&:to_s).to_set
      # 'all' => 'True'
      Docker::Image.all().map do |docker_obj|
        next if docker_obj.untagged?
        # if any name matches a manifest, gift it; skip the docker_obj otherwised
        name = img_names.intersection(docker_obj.names).first or next
        self[name].docker_obj = docker_obj
      end
      self
    end

  end

end
