module Rucker
  class PortBinding < Rucker::Manifest::Base
    field :desc,  :string,  doc: "Description of the port"
    field :hport, :integer, doc: "Host port to bind"
    field :cport, :integer, doc: "Container port to bind"
    field :proto, :string,  doc: "Protocol: UDP or TCP", default: 'tcp'
    field :bind,  :string,  doc: "IP address this port binds to"

    # Should this port be published to the docker host, or only exposed to
    # containers that explicitly link it?
    def published?
      !! hport
    end

    def to_s
      [ (bind  ? "#{bind}:"      : nil),
        (hport ? "#{hport}:"     : nil),
        cport,
        (proto == 'udp' ? '/udp' : nil) ].compact.join
    end

    def cport_proto
      "#{cport}/#{proto}"
    end

    def bind
      # force the default if the host port is present; '123:456' shouldn't double up '0.0.0.0:123:456'
      val = super
      val = write_attribute(:bind, '0.0.0.0') if published? && val.blank?
      val
    end

    # bind:hport:cport~desc or bind::cport~desc
    BIND_HC_RE     = %r{\A (\d+\.\d+\.\d+\.\d+) : (\d+)? : (\d+) (?:/(tcp|udp))? (?:~([a-z0-9_]+))? \z}x
    # hport:cport~desc
    HPORT_CPORT_RE = %r{\A                        (\d+)  : (\d+) (?:/(tcp|udp))? (?:~([a-z0-9_]+))? \z}x
    # cport~desc
    CPORT_RE       = %r{\A                                 (\d+) (?:/(tcp|udp))? (?:~([a-z0-9_]+))? \z}x
    #
    def self.parse_portstr(str)
      db = '0.0.0.0'
      # Could I do this with one regexp? probably, but I wouldn't want to read the conditionals that would ensue
      case str.to_s
      when CPORT_RE       then {                      cport: $1, proto: ($2||'tcp'), desc: $3 }
      when HPORT_CPORT_RE then { bind: db, hport: $1, cport: $2, proto: ($3||'tcp'), desc: $4 }
      when BIND_HC_RE     then { bind: $1, hport: $2, cport: $3, proto: ($4||'tcp'), desc: $5 }
      else
        warn "Can't parse port description #{str}"
        return str
      end
    end

    def self.receive(val)
      super( val.is_a?(String)||val.is_a?(Integer) ? parse_portstr(val) : val)
    end

    def collection_key()        to_s ; end
    def set_collection_key(key) receive!(parse_portstr(key)); end
  end

  class PortBindingCollection < KeyedCollection
    def exposed_creation_hshs
      # reject(|port| port.published? ).
      items.map{|port| { port.cport_proto => {} } }
    end
    def published_creation_hshs
      hsh = Hash.new{|h,v| h[v] = [] } # auto-vivify
      items.select{|port| port.published? }.each do |port|
        hsh[port.cport_proto] << { 'HostIp' => port.bind, 'HostPort' => port.hport.to_s }
      end
      hsh
    end
  end
end
