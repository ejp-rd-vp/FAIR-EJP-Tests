class OpenAPI
  attr_accessor :title, :tests_metric, :description, :applies_to_principle, :organization, :org_url, :version
  attr_accessor :responsible_developer, :email, :developer_ORCiD, :protocol, :host, :basePath, :path, :response_description, :schemas

  def initialize(title:, tests_metric:, description:, applies_to_principle:, organization:, org_url:, responsible_developer:, 
    email:, developer_ORCiD:, protocol:, host:, basePath:, path:, response_description:, schemas:, version:)

    @title = title
    @tests_metric = tests_metric
    @description = description 
    @applies_to_principle = applies_to_principle 
    @version = version 
    @organization = organization 
    @org_url = org_url 
    @responsible_develper = responsible_developer 
    @email = email 
    @developer_ORCiD = developer_ORCiD 
    @host = host 
    @protocol = protocol 
    @basePath = basePath 
    @path = path 
    @response_description = response_description 
    @schemas = schemas 
  end


  def get_api
    message = <<~"EOF_EOF"
      swagger: '2.0'
      info:
       version: '#{@version}'
       title: "#{@title}"
       x-tests_metric: '#{@tests_metric}'
       description: >-
         #{@description}
       x-applies_to_principle: "#{@applies_to_principle}"
       contact:
        x-organization: "#{@organization}"
        url: "#{@org_url}"
        name: '#{@responsible_develper}'
        x-role: "responsible developer"
        email: #{@email}
        x-id: '#{developer_ORCiD}'
      host: #{@host}
      basePath: #{@basePath}
      schemes:
        - #{@protocol}
      paths:
       #{@path}:
        post:
         parameters:
          - name: content
            in: body
            required: true
            schema:
              $ref: '#/definitions/schemas'
         consumes:
           - application/json
         produces:#{'  '}
           - application/json
         responses:
           "200":
             description: >-
              #{@response_description}
      definitions:
        schemas:
          required:
EOF_EOF

    schemas.each_key do |key|
      message += "     - #{key}\n"
    end
    message += "    properties:\n"
    schemas.each_key do |key|
      message += "        #{key}:\n"
      message += "          type: #{schemas[key][0]}\n"
      message += "          description: >-\n"
      message += "            #{schemas[key][1]}\n"
    end

    message
  end
end