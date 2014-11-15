require 'gorillib/metaprogramming/delegation'
require 'gorillib/metaprogramming/class_attribute'

module Rucker

  #
  # KeyedCollection helps models with their plural properties: the special
  # case of an enumerable collection in which
  #
  # * items are uniquely labeled by their #collection_key method (and optionally
  #   have a #set_collection_key= method to set it)
  #
  # * items share a common type: "a post has many `Comment`s".
  #
  # * items may want to hold a reference back to the containing model
  #
  # * items are enumerated as themselves (i.e. like an array) but retrieved by
  # * key (i.e. like a hash)
  #
  # The set of methods is purposefully sparse. Anything beyond this should
  # probably be a method on the owner model -- in fact, most access should be
  # done with the owner model. But if you want to use `select`, `invert`, etc,
  # just invoke `to_hash` or `to_a` and work with the copy it gives you.
  #
  class KeyedCollection
    # [{Symbol => Object}] The actual store of items -- not for you to mess with
    attr_reader :clxn
    protected   :clxn
    # [Gorillib::Model] The model class that items instantiate
    attr_reader :model
    protected   :model

    # Object that owns this collection
    attr_reader :belongs_to

    # include Gorillib::Model
    def initialize(opts={})
      @clxn       = Hash.new
      @model      = opts[:of] or raise(ArgumentError, "#{self.class} requires a model")
      @belongs_to = opts[:belongs_to] if opts[:belongs_to]
    end

    # Adds an item in-place using the value of item.collection_key.  Items
    # added to the collection (via `add`, `[]=`, `initialize`, etc) all pass
    # through the `add` method: you should override this in subclasses to add
    # any gatekeeper behavior.
    #
    # @return [Object] the item
    def add(item)
      @clxn[key_for(item)] = item
    end

    # items arriving from the outside world should pass first through
    # receive_item, not directly to add. This lets you do type correction to
    # things coming from eg. a JSON object
    def receive_item(item, key=nil)
      item = model.receive(item)
      item.set_collection_key(key) if key.present?
      add(item)
    end

    def key_for(item)
      item.collection_key.to_sym
    end

    def all_present?(of_keys)
      of_keys.all?{|key| @clxn.include?(key.to_sym) }
    end

    def missing_keys(keys)
      keys.map(&:to_sym) - self.keys
    end

    #
    # Barebones enumerable methods
    #

    delegate :[], :fetch, :delete, :include?,         :to => :clxn
    delegate :keys, :values, :each_pair, :each_value, :to => :clxn
    delegate :length, :size, :empty?, :blank?,        :to => :clxn

    # @return [Array] an array holding the items
    def to_a    ; values    ; end
    # @return [{Symbol => Object}] a hash of key=>item pairs
    def to_hash ; clxn.dup  ; end

    # iterate over each value in the collection
    def each(&blk); each_value(&blk) ; end

    # iterate over each value in the collection
    def map(*args, &blk) values.map(*args, &blk) ; end

    # Adds item, returning the collection itself.
    # @return [Gorillib::Collection] the collection
    def <<(item)
      add(item)
      self
    end

    # calls #set_collection_key on the item
    def []=(key, item)
      item.set_collection_key(key)
      add(item)
    end

    def slice(*keys)
      if keys == [:_all]
        self.to_a
      else
        keys.map{|key| clxn[key] }
      end
    end

    #
    # Model Machinery
    #
    
    # Receive items in-place, replacing any existing item with that key.
    #
    # Individual items are added using #receive_item -- if you'd like to perform
    # any conversion or modification to items, do it there
    #
    # @param  other [{Symbol => Object}, Array<Object>] a hash of key=>item pairs or a list of items
    # @return [Gorillib::Collection] the collection
    def receive!(other)
      if other.respond_to?(:each_pair)
        other.each_pair{|key, item| receive_item(item, key) }
      elsif other.respond_to?(:each)
        other.each{|item|           receive_item(item) }
      else
        raise "A collection can only receive something that is enumerable: got #{other.inspect}"
      end
      self
    end

    # Create a new collection and add the given items to it
    # (if given an existing collection, just returns it directly)
    def self.receive(items, *args)
      return items if native?(items)
      coll = self.new(*args)
      coll.receive!(items)
      coll
    end

    # Used by owner model while receiving possibly-preassembled content. An
    # instance of this or some subclass does not need any transformation, and so
    # can be received directly; a hash does.
    #
    # @param  obj [Object] the object that will be received
    # @return [true, false] true if the item does not need conversion
    def self.native?(obj)
      obj.is_a?(self)
    end

    # Two collections are equal if they have the same class and their contents are equal
    #
    # @param [Rucker::KeyedCollection, Object] other The other collection to compare
    # @return [true, false] True if attributes are equal and other is instance of the same Class
    def ==(other)
      return false unless other.instance_of?(self.class)
      clxn == other.send(:clxn)
    end

    # @return [String] string describing the collection's array representation
    def to_s
      to_a.to_s
    end
    
    # @return [String] string describing the collection's array representation
    def inspect
      key_width = [keys.map{|key| key.to_s.length + 1 }.max.to_i, 45].min
      guts = clxn.map{|key, val| "%-#{key_width}s %s" % ["#{key}:", val.inspect] }.join(",\n   ")
      ["c##{model}{ ", guts, ' }'].join
    end

    def inspect_compact
      ["c{ ", keys.join(", "), ' }'].join
    end

  end
end
