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

}