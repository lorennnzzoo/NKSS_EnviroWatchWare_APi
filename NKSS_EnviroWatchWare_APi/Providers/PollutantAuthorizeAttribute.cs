using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;

namespace NKSS_EnviroWatchWare_APi.Providers
{
    public class PollutantAuthorizeAttribute : AuthorizationFilterAttribute
    {

        private const string AuthorizationHeaderName = "Authorization";

        public override void OnAuthorization(HttpActionContext actionContext)
        {
            if (actionContext.Request.Headers.Contains(AuthorizationHeaderName))
            {
                var apiKey = actionContext.Request.Headers.GetValues(AuthorizationHeaderName).FirstOrDefault();

                if (!string.IsNullOrWhiteSpace(apiKey) && IsValidApiKey(apiKey))
                {
                    return;
                }
            }

            actionContext.Response = actionContext.Request.CreateResponse(HttpStatusCode.Unauthorized, "Invalid API Key");
        }

        private bool IsValidApiKey(string apiKey)
        {
            if (string.IsNullOrWhiteSpace(apiKey))
            {
                return false;
            }
            return KeyValidityHelper.CheckKeyValidity(apiKey);
        }
    }
}