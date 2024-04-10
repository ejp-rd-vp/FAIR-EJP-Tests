require_relative File.dirname(__FILE__) + '/../lib/harvester.rb'

class FAIRTest
  def self.ejp_base_metadata_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-2.0.0',
      testname: 'EJP-RD: Test for Core Metadata',
      testid: 'ejp_base_metadata',
      description: 'Test if the minimal metadata requirements are met to be in the EJP VP',
      metric: 'https://example.org/none',
      principle: 'none'
    }
  end

  def self.ejp_base_metadata(guid:)
    FAIRChampion::Output.clear_comments

    output = FAIRChampion::Output.new(
      testedGUID: guid,
      name: ejp_base_metadata_meta[:testname],
      version: ejp_base_metadata_meta[:testversion],
      description: ejp_base_metadata_meta[:description],
      metric: ejp_base_metadata_meta[:metric]
    )

    output.comments << "INFO: TEST VERSION '#{ejp_base_metadata_meta[:testversion]}'\n"

    metadata = FAIRChampion::Harvester.resolveit(guid) # this is where the magic happens!

    metadata.comments.each do |c|
      output.comments << c
    end

    if metadata.guidtype == 'unknown'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The identifier #{guid} did not match any known identification system.\n"
      return output.createEvaluationResponse
    end

    hash = metadata.hash
    graph = metadata.graph
    properties = FAIRChampion::Harvester.deep_dive_properties(hash)
    #############################################################################################################
    #############################################################################################################
    #############################################################################################################
    #############################################################################################################

    output.comments << "INFO: Searching metadata for likely identifiers to the data record\n"

    prefixes = "PREFIX dcat: <http://www.w3.org/ns/dcat#>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>
    PREFIX ejp: <https://w3id.org/ejp-rd/vocabulary#>
    "

    # test discoverability
    output.comments << "INFO:  Testing for VPDiscoverable.\n"
    query = SPARQL.parse("#{prefixes}
      select ?s where {?s ejp:vpConnection ejp:VPDiscoverable }")
    results = query.execute(g)
    if results.any?
      output.comments << "INFO: Found the EJP VPDiscoverable property somewhere in the FDP '\n"
    else
      output.score = 'fail'
      output.comments << "FAILURE: Nothing in the FDP was flagged to be discoverable\n"
      return output.createEvaluationResponse
    end

    discoverables = results.map {|r| r[:s].to_s}


    requiredpredicates = %w[dcat:theme dcat:contactPoint dct:description
                            dct:isPartOf dct:keyword dct:language dct:license
                            dct:publisher dct:title dcat:contactPoint dcat:landingPage]

    optionalpredicates = %w[foaf:logo dct:issued dct:modified ]

    discoverables.each do |d|
      optionalpredicates.each do |p|
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

    discoverables.each do |d|
      requiredpredicates.each do |p|
        output.comments << "INFO:  Testing Discoverable #{d} for mandatory property #{p}.\n"
        query = SPARQL.parse("#{prefixes}
          SELECT ?o WHERE { <#{d}> #{p} ?o }")
        results = query.execute(g)
        if results.any?
          output.comments << "INFO: Found the EJP mandatory metadata element #{p} on the Discoverable entity #{d}'\n"

        else
          output.comments <<  "WARN: the mandatory metadata element #{p} could not be found on the Discoverable entity #{d}\n"
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

    output.createEvaluationResponse
  end

  def self.ejp_base_metadata_api
    schemas = { 'subject' => ['string', 'the GUID being tested'] }

    api = OpenAPI.new(title: ejp_base_metadata_meta[:testname],
                      description: ejp_base_metadata_meta[:description],
                      tests_metric: ejp_base_metadata_meta[:metric],
                      version: ejp_base_metadata_meta[:testversion],
                      applies_to_principle: ejp_base_metadata_meta[:principle],
                      organization: 'EJP-RD',
                      org_url: 'https://ejprarediseases.org//',
                      responsible_developer: 'Mark D Wilkinson',
                      email: 'mark.wilkinson@upm.es',
                      developer_ORCiD: '0000-0001-6960-357X',
                      protocol: ENV.fetch('TEST_PROTOCOL', nil),
                      host: ENV.fetch('TEST_HOST', nil),
                      basePath: ENV.fetch('TEST_PATH', nil),
                      path: fc_data_authorization_meta[:testid],
                      response_description: 'The response is "pass", "fail" or "indeterminate"',
                      schemas: schemas)
    api.get_api
  end
end
