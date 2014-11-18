module Rucker
  module Common
    module Image
      #
      def short_id()    id[0..12] ; end
      #
      def parsed_name
        @parsed_name = Rucker::Common::Image.split_name(name)
      end

      def ns()     @ns     ||= parsed_name[:ns]     ; end
      def slug()   @slug   ||= parsed_name[:slug]   ; end
      def tag()    @tag    ||= parsed_name[:tag]    ; end
      def family() @family ||= parsed_name[:family] ; end

      # used by KeyedCollection to know how to index these
      def collection_key()        name ; end
      # used by KeyedCollection to know how to index these
      def set_collection_key(key) receive_name(key) ; end

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
    end
  end

  class Image < Rucker::Manifest::Base
    include Rucker::Common::Image
    #
    field :id,          :string,  doc: "Hexadecimal unique id"
    field :name,        :string,  doc: "Full name -- ns/slug:tag -- for image"
    #
    field :external,    :boolean, doc: 'Is this one of your images, i.e. it should be included in a push or build?'
    field :kind,        :symbol,  doc: ':data for containers-used-as-volumes'
  end


  class ImageCollection < KeyedCollection
    # list of images with given family, sorted with 'latest' at front.
    def with_family(family)
      clxn.find_all{|key, item| item.family.to_s == family.to_s }.sort_by(&:comparable_name)
    end
  end

end
