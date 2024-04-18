require_relative "#{File.dirname(__FILE__)}/../lib/fdp.rb"
require_relative "#{File.dirname(__FILE__)}/../lib/openapi.rb"

class FAIRTest
  def self.ejp_base_metadata_meta
    # FAIRTest::HARVESTER_VERSION == "1" unless FAIRTest::HARVESTER_VERSION
    {
      # testversion: "#{HARVESTER_VERSION}:Tst-0.1.0",
      testversion: "1:Tst-0.1.0",
      testname: 'EJP-RD: Test for Core Metadata',
      testid: 'ejp_base_metadata',
      description: 'Test if the minimal metadata requirements are met to be in the EJP VP',
      metric: 'https://example.org/none',
      principle: 'none',
    }
  end

  def self.ejp_base_metadata(guid:)
    FAIRChampion::Output.clear_comments

    output = FAIRChampion::Output.new(
      testedGUID: guid,
      name: ejp_base_metadata_meta[:testname],
      version: ejp_base_metadata_meta[:testversion],
      description: ejp_base_metadata_meta[:description],
      metric: ejp_base_metadata_meta[:metric],
    )

    output.comments << "INFO: TEST VERSION '#{ejp_base_metadata_meta[:testversion]}'\n"

    # metadata = FAIRChampion::Harvester.resolveit(guid) # this is where the magic happens!
    fdp = FDP.new(address: guid)
    # metadata = FAIRChampion::Harvester.resolveejp(guid) # this is where the magic happens!
    # warn fdp.inspect
    # warn fdp.graph
    # warn fdp.graph.size


    graph = fdp.graph
    #############################################################################################################
    #############################################################################################################
    #############################################################################################################
    #############################################################################################################

    output.comments << "INFO: Beginning EJP-Specific tests for Core Metadata Elements, required by the Virtual Platform\n"

    g = graph
    prefixes = "PREFIX dcat: <http://www.w3.org/ns/dcat#>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>
    PREFIX ejp: <https://w3id.org/ejp-rd/vocabulary#>
    "

    output.comments << "INFO: Checking for the use of the deprecated pur.org vocabulary\n"

    query = SPARQL.parse("#{prefixes}
    select DISTINCT ?p where {?s ?p ?o . FILTER(CONTAINS(STR(?p), 'purl.archive.org/ejp-rd/'))}")
    results = query.execute(g)
    if results.any?
      output.score = 'fail'
      output.comments << "FAILURE: FDP is still using the deprecated purl predicates\n"
      return output.createEvaluationResponse
    else
      output.comments << "INFO: Didn't see any deprecated predicates.\n"
    end



    # test discoverability
    output.comments << "INFO:  Testing for existence of a VPDiscoverable resource within the FDP record.\n"
    query = SPARQL.parse("#{prefixes}
      select ?s where {?s ejp:vpConnection ejp:VPDiscoverable }")
    results = query.execute(g)
    if results.any?
      # warn "one"
      output.comments << "INFO: Found the EJP VPDiscoverable property somewhere in the FDP.\n"
    else
      # warn "two"
      output.score = 'fail'
      output.comments << "FAILURE: Nothing in the FDP was flagged to be VPDiscoverable.\n"
      return output.createEvaluationResponse
    end

    discoverables = results.map { |r| r[:s].to_s }

    requiredpredicates = %w[dcat:theme dcat:contactPoint dct:description
                            dct:keyword dct:language dct:license
                            dct:publisher dct:title dcat:contactPoint dcat:landingPage]

    specialpredicates = %w{dct:isPartOf}
    
    optionalpredicates = %w[foaf:logo dct:issued dct:modified]

    discoverables.each do |d|
      optionalpredicates.each do |p|
        # warn "three"

        output.comments << "INFO:  Testing Discoverable #{d} for optional property #{p}.\n"
        query = SPARQL.parse("#{prefixes}
          SELECT ?o WHERE { <#{d}> #{p} ?o }")
        results = query.execute(g)
        output.comments << if results.any?
                             "INFO: Found the EJP recommended metadata element #{p} on the Discoverable entity #{d}'\n"
                           else
                             "WARN: the recommended metadata element #{p} could not be found on the Discoverable entity #{d}\n"
                           end
      end
    end

    failflag = false
    # warn "four"

    discoverables.each do |d|
      requiredpredicates.each do |p|
        output.comments << "INFO:  Testing Discoverable #{d} for mandatory property #{p}.\n"
        query = SPARQL.parse("#{prefixes}
          SELECT ?o WHERE { <#{d}> #{p} ?o }")
        results = query.execute(g)
        if results.any?
          # warn "five"
          output.comments << "INFO: Found the EJP mandatory metadata element #{p} on the Discoverable entity #{d}'\n"
        else
          # warn "six"
          output.comments << "WARN: the mandatory metadata element #{p} could not be found on the Discoverable entity #{d}\n"
          failflag = true
        end
      end
    end
    if failflag
      output.score = 'fail'
      output.comments << "FAILURE: At least one required metadata element is missing\n"
    else
      output.score = 'pass'
      output.comments << "SUCCESS: Found all of the EJP reqired metadata elements\n"
    end

    # warn output.inspect
    output.createEvaluationResponse
  end

  def self.ejp_base_metadata_api
    schemas = { 'subject' => ['string', 'the GUID being tested'] }

    api = OpenAPI.new(title: ejp_base_metadata_meta[:testname],
                      description: ejp_base_metadata_meta[:description],
                      tests_metric: ejp_base_metadata_meta[:metric],
                      version: ejp_base_metadata_meta[:testversion],
                      applies_to_principle: ejp_base_metadata_meta[:principle],
                      path: ejp_base_metadata_meta[:testid],
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
