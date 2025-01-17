using Microsoft.Owin;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Web;
using System.Web.Cors;

namespace NKSS_EnviroWatchWare_APi.MiddlerWare
{
    public class CorsMiddleware : OwinMiddleware
    {
        private readonly CorsPolicy _policy;

        public CorsMiddleware(OwinMiddleware next, CorsPolicy policy)
            : base(next)
        {
            _policy = policy;
        }

        public override async Task Invoke(IOwinContext context)
        {
            //if (context.Request.Path.ToString().StartsWith("/Auth/", StringComparison.OrdinalIgnoreCase))
            //{
                var origin = context.Request.Headers.Get("Origin");

                if (_policy.Origins.Contains(origin))
                {
                    context.Response.Headers.Add("Access-Control-Allow-Origin", new[] { origin });
                    context.Response.Headers.Add("Access-Control-Allow-Headers", new[] { "accept,authorization,content-type,origin" });
                    context.Response.Headers.Add("Access-Control-Allow-Methods", new[] { "GET,POST,PUT,DELETE,OPTIONS" });
                    context.Response.Headers.Add("Access-Control-Allow-Credentials", new[] { "true" });
                }

                if (context.Request.Method == "OPTIONS")
                {
                    context.Response.StatusCode = 200;
                    return;
                }
            //}

            await Next.Invoke(context);
        }
    }
}
