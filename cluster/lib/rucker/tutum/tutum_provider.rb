

module Rucker
  module Tutum
    class TutumProvider < Rucker::Tutum::TutumBase
      include Rucker::Manifest::HasState
      #
      field :name, :symbol, default: :world
      field :layout_file, :string
      #
      # collection :clusters,    Rucker::Manifest::ClusterCollection
      # collection :images,      Rucker::Manifest::ImageCollection
      # collection :extra_ports, Rucker::Manifest::PortBindingCollection

      
      
    end
  end
end
