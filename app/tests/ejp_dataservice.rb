require_relative "#{File.dirname(__FILE__)}/../lib/fdp.rb"
require_relative "#{File.dirname(__FILE__)}/../lib/openapi.rb"
require 'sparql'

class FAIRTest
  def self.ejp_dataservice_meta
    # FAIRTest::HARVESTER_VERSION == "1" unless FAIRTest::HARVESTER_VERSION
    {
      # testversion: "#{HARVESTER_VERSION}:Tst-0.1.0",
      testversion: "1:Tst-0.1.0",
      testname: 'EJP-RD: Test for correctly configured data service',
      testid: 'ejp_dataservice',
      description: 'Test if the minimal DataService metadata requirements are met to be in the EJP VP',
      metric: 'https://example.org/none',
      principle: 'none',
    }
  end

  def self.ejp_dataservice(guid:)
    FAIRChampion::Output.clear_comments

    output = FAIRChampion::Output.new(
      testedGUID: guid,
      name: ejp_dataservice_meta[:testname],
      version: ejp_dataservice_meta[:testversion],
      description: ejp_dataservice_meta[:description],
      metric: ejp_dataservice_meta[:metric],
    )

    output.comments << "INFO: TEST VERSION '#{ejp_dataservice_meta[:testversion]}'\n"

    # metadata = FAIRChampion::Harvester.resolveit(guid) # this is where the magic happens!
    fdp = FDP.new(address: guid)

    graph = fdp.graph
    #############################################################################################################
    #############################################################################################################
    #############################################################################################################
    #############################################################################################################

    output.comments << "INFO: Beginning EJP-Specific tests for Data Services, required by the Virtual Platform\n"

    g = graph
    prefixes = "PREFIX dcat: <http://www.w3.org/ns/dcat#>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>
    PREFIX ejp: <https://w3id.org/ejp-rd/vocabulary#>
    "

    # test discoverability
    warn "testing discoverability"
    output.comments << "INFO: finding things that are VPDiscoverable.\n"
    query = SPARQL.parse("#{prefixes}
      SELECT ?s WHERE {?s ejp:vpConnection ejp:VPDiscoverable }")
    results = query.execute(g)
    if results.any?
      output.comments << "INFO: Found the EJP VPDiscoverable property somewhere in the FDP.\n"
    else
      output.score = 'fail'
      output.comments << "FAILURE: Nothing in the FDP was flagged to be VPDiscoverable.\n"
      return output.createEvaluationResponse
    end
    discoverables = results.map { |r| r[:s].to_s }



    # Find Discoverable Services
    warn "Finding services"
    output.comments << "INFO: Filtering discoverables to only Data Services.\n"
    valuesstring = discoverables.map {|s| "<#{s}>"}
    query ="#{prefixes}
    SELECT ?s WHERE {
      VALUES ?s { #{valuesstring.join("\s")} }
      ?s a dcat:DataService .
      }"

    warn "service query", query
    query = SPARQL.parse(query)    
    warn "parsed, now executing"
    results = query.execute(g)
    warn "query results", results.inspect
    if results.any?
      output.comments << "INFO: Found at least one DataService flagged to be VPDiscoverable.\n"
    else
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: No DataService was flagged to be VPDiscoverable.\n"
      return output.createEvaluationResponse
    end
    discoverableservices = results.map { |r| r[:s].to_s }


    # Check Required Properties
    warn "testing service properties"
    output.comments << "INFO: Checking properties of each Data Service.\n"
    discoverableservices.each do |service|
      warn "testing that it isn't a FAIR Data Point"
      query = SPARQL.parse("#{prefixes}
      SELECT DISTINCT ?type WHERE {
        <#{service}> a ?type . }")
      results = query.execute(g)
      types = results.map { |r| r[:type].to_s }
      if types.include? "https://w3id.org/fdp/fdp-o#FAIRDataPoint"
        output.comments << "INFO: This Data Service is the FAIR Data Point itself... moving on!\n"
        next
      end

      warn "testing service properties #{service}"
      query = SPARQL.parse("#{prefixes}
      SELECT DISTINCT ?p WHERE {
        <#{service}> ?p ?o . }")
      results = query.execute(g)
      unless results.any?
        output.score = 'fail'
        output.comments << "FAILURE: Oddly, the DataService #{service} had no properties at all.\n"
        return output.createEvaluationResponse
      end
      preds = results.map { |r| r[:p].to_s }
      # dcat:endpointURL
      # dcat:endpointDescription
      failflag = false
      warn "testing service properties endpoint stuff"
      if preds.include? "http://www.w3.org/ns/dcat#endpointURL"
        if preds.include? "http://www.w3.org/ns/dcat#endpointDescription"
          output.comments << "INFO: Both required endpointURL and endpointDescription were found for Data Service #{service}.\n"
        else
          output.comments << "WARN: both endpointURL and endpointDescription are required, but endpointDescription was lacking for Data Service #{service}.\n"
          failflag = true
        end
        # now invert the test
      elsif preds.include? "http://www.w3.org/ns/dcat#endpointDescription"
        if preds.include? "http://www.w3.org/ns/dcat#endpointURL"
          output.comments << "INFO: Both required endpointURL and endpointDescription were found for Data Service #{service}.\n"
        else
          output.comments << "WARN: both endpointURL and endpointDescription are required, but endpointURL was lacking for Data Service #{service}.\n"
          failflag = true
        end
      elsif preds.include? "http://www.w3.org/ns/dcat#landingPage"
        warn "testing service landingpage"
        output.comments << "INFO: A landingPage was found for Data Service #{service}.\n"
      end

      if failflag
        output.score = 'fail'
        output.comments << "FAILURE: The Data Service #{service} is incorrectly described.  See previous log messages for more information.\n"
        return output.createEvaluationResponse
      end

      # now test for dcat:type
      warn "testing service type"
      if preds.include? "http://purl.org/dc/terms/type"
        output.comments << "INFO: a dcterms:type predicate was found for Data Service #{service}.\n"
      else
        output.score = 'fail'
        output.comments << "FAILURE: The required dcterms:type property was not found for Data Service #{service}.\n"
        return output.createEvaluationResponse
      end

      # now test specifically for Beacon stuff
      warn "testing beacon config"
      query = SPARQL.parse("#{prefixes}
      SELECT DISTINCT ?type WHERE {
        <#{service}> dct:type ?type . }")
      results = query.execute(g)
      unless results.any?  # this should never be true, since it is caught in the previous section, but... whatever!
        output.score = 'fail'
        output.comments << "FAILURE: The DataService #{service} had no dcterms:type.\n"
        return output.createEvaluationResponse
      end
      types = results.map { |r| r[:type].to_s }
      if types.include?("https://w3id.org/ejp-rd/vocabulary#VPBeacon2_individuals") || types.include?("https://w3id.org/ejp-rd/vocabulary#VPBeacon2_catalog")
        unless preds.include?("http://www.w3.org/ns/dcat#endpointDescription") && preds.include?("http://www.w3.org/ns/dcat#endpointURL")
          output.score = 'fail'
          output.comments << "FAILURE: Beacon services (both catalog and individuals) must have both an endpointURL and an endpointDescription.\n"
          return output.createEvaluationResponse
        end
        output.comments << "INFO: Found a correctly configured Beacon service #{service}.\n"
      else
        output.comments << "INFO: Found a Data Service that is not one of the Beacon types; we have no expectations, so moving on....\n"
      end
    end

    warn "sending a pass!"

    output.score = 'pass'
    output.comments << "SUCCESS: All Data Services appear to be correctly configured for VP consumption.\n"
    return output.createEvaluationResponse
  end


  def self.ejp_dataservice_api
    schemas = { 'subject' => ['string', 'the GUID being tested'] }

    api = OpenAPI.new(title: ejp_dataservice_meta[:testname],
                      description: ejp_dataservice_meta[:description],
                      tests_metric: ejp_dataservice_meta[:metric],
                      version: ejp_dataservice_meta[:testversion],
                      applies_to_principle: ejp_dataservice_meta[:principle],
                      path: ejp_dataservice_meta[:testid],
                      organization: 'EJP-RD',
                      org_url: 'https://ejprarediseases.org//',
                      responsible_developer: 'Mark D Wilkinson',
                      email: 'mark.wilkinson@upm.es',
                      developer_ORCiD: '0000-0001-6960-357X',
                      protocol: ENV.fetch('TEST_PROTOCOL', nil),
                      host: ENV.fetch('TEST_HOST', nil),
                      basePath: ENV.fetch('TEST_PATH', nil),
                      response_description: 'The response is "pass", "fail" or "indeterminate"',
                      schemas: schemas)
    api.get_api
  end
end
