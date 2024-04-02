module FAIRChampion
  class MetadataObject

    @@comments = []
    attr_accessor :hash, :graph, :guidtype, :full_response, :finalURI

    # a hash of metadata 
    # a RDF.rb graph of metadata  
    # an array of comments  
    # the type of GUID that was detected # will be an array of Net::HTTP::Response

    def initialize()
      @hash = {}
      @graph = RDF::Graph.new
      @full_response = []
      @finalURI = []
    end

    def comments
      @@comments
    end 
    def self.comments
      @@comments
    end 

    def self.clear_comments
      @@comments = []
    end
    
    def merge_hash(hash)
      # $stderr.puts "\n\n\nIncoming Hash #{hash.inspect}"
      self.hash = self.hash.merge(hash)
    end

    def merge_rdf(triples) # incoming list of triples
      graph << triples
      graph
    end

    def rdf
      graph
    end
  end
end
