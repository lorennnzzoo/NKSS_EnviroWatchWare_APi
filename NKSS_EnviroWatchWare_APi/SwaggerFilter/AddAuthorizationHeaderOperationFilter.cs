using Swashbuckle.Swagger;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Http.Description;

namespace NKSS_EnviroWatchWare_APi.SwaggerFilter
{
    public class AddAuthorizationHeaderOperationFilter : Swashbuckle.Swagger.IOperationFilter
    {

        public void Apply(Operation operation, SchemaRegistry schemaRegistry, ApiDescription apiDescription)
        {
            if (operation.parameters == null)
                operation.parameters = new List<Swashbuckle.Swagger.Parameter>();

            operation.parameters.Add(new Swashbuckle.Swagger.Parameter
            {
                name = "Authorization",
                @in = "header",
                description = "Bearer token authorization",
                required = false, // Set this to true if the token is required
                type = "string"
            });
        }
    }


    public class AuthTokenOperation : IDocumentFilter
    {
        public void Apply(SwaggerDocument swaggerDoc, SchemaRegistry schemaRegistry, IApiExplorer apiExplorer)
        {
            swaggerDoc.paths.Add("/Auth/Login", new PathItem
            {
                post = new Operation
                {
                    tags = new List<string> { "Auth" },
                    consumes = new List<string>
                {
                    "application/x-www-form-urlencoded"
                },
                    parameters = new List<Parameter> {
                    new Parameter
                    {
                        type = "string",
                        name = "grant_type",
                        required = true,
                        @in = "formData",
                        @default="password"
                    },
                    new Parameter
                    {
                        type = "string",
                        name = "username",
                        required = false,
                        @in = "formData"
                    },
                    new Parameter
                    {
                        type = "string",
                        name = "password",
                        required = false,
                        @in = "formData"
                    }
                }
                }
            });
        }
    }


}