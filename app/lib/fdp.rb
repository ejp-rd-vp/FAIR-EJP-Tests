

class FDP
  attr_accessor :graph, :address, :called

  def initialize(address:)
    @graph = RDF::Graph.new
    @address = address  # address of this FDP
    @called = []  # has this address already been called?  List of known
    warn "refreshing"
    load(address: address)  # THIS IS A RECURSIVE FUNCTION THAT FOLLOWS ldp:contains 
#    warn "FINALGRAPH", @graph
  end

  def self.load_from_cache(vp:, marshalled:)
    begin
      warn "thawing file #{marshalled}"
      fdpstring = File.read(marshalled)
      fdp = Marshal.load(fdpstring)
    rescue StandardError
      nil
    end
    fdp
  end

  def load(address:)
    return if called.include? address

    called << address
    body = {}
    address = address.gsub(%r{/$}, "")
    warn "getting #{address}"
    begin
      r = RestClient::Request.execute(
        :url => address, 
        :method => :get, 
        :verify_ssl => false
      )
      body = r.body if r.body
      # warn r.body
    rescue e
      warn "#{address} didn't resolve"
    end

    unless body
      address += "?format=ttl"
      warn "getting #{address}"
      begin
        r = RestClient::Request.execute(
          :url => address, 
          :method => :get, 
          :verify_ssl => false
        )
        body = r.body if r.body
        # warn r.body
      rescue e
        warn "#{address} didn't resolve"
      end
    end
    # warn "final", body
    parse(message: body) if body
  end

  def parse(message:)
    data = StringIO.new(message)
    RDF::Reader.for(:turtle).new(data) do |reader|
      reader.each_statement do |statement|
        warn "statement", statement
        @graph << statement
        if statement.predicate.to_s == "http://www.w3.org/ns/ldp#contains"
          contained_thing = statement.object.to_s
          self.load(address: contained_thing) # this ends up being recursive... careful!
        end
      end
    end
    # warn "graph after parsing", @graph
  end

  def freezeme
    address = Digest::SHA256.hexdigest @address
    f = File.open("./cache/#{address}.marsh", "w")
    str = Marshal.dump(self).force_encoding("ASCII-8BIT")
    f.puts str
    f.close
  end



end
