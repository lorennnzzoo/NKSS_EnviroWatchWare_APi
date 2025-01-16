using NLog;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Web;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;

namespace NKSS_EnviroWatchWare_APi.Logging
{
    public class LoggingFilter : ActionFilterAttribute
    {
        private static readonly Logger Logger = LogManager.GetCurrentClassLogger();

        // This method will log the request details
        public override async Task OnActionExecutingAsync(HttpActionContext actionContext, System.Threading.CancellationToken cancellationToken)
        {
            var request = actionContext.Request;

            // Log the Request Method and URI
            Logger.Info($"Request Method: {request.Method}");
            Logger.Info($"Request URI: {request.RequestUri}");

            // Log the Request Headers
            Logger.Info("Request Headers:");
            foreach (var header in request.Headers)
            {
                Logger.Info($"{header.Key}: {string.Join(", ", header.Value)}");
            }

            // Log the Request Body (if applicable)
            if (request.Content != null)
            {
                string requestBody = await request.Content.ReadAsStringAsync();
                Logger.Info($"Request Body: {requestBody}");
            }

            await base.OnActionExecutingAsync(actionContext, cancellationToken);
        }

        // This method will log the response details
        public override async Task OnActionExecutedAsync(HttpActionExecutedContext actionExecutedContext, System.Threading.CancellationToken cancellationToken)
        {
            var response = actionExecutedContext.Response;

            if (response != null)
            {
                // Log the Response Status Code
                Logger.Info($"Response Status Code: {response.StatusCode}");

                // Log the Response Body (if applicable)
                if (response.Content != null)
                {
                    string responseBody = await response.Content.ReadAsStringAsync();
                    Logger.Info($"Response Body: {responseBody}");
                }
            }

            await base.OnActionExecutedAsync(actionExecutedContext, cancellationToken);
        }
    }
}