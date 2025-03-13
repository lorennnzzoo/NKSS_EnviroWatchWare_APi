using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize(Roles = "Demo")]
    [RoutePrefix("Configuration")]
    public class ConfigurationController : ApiController
    {
        private readonly ConfigurationService configurationService;
        public ConfigurationController(ConfigurationService _configurationService)
        {
            configurationService = _configurationService;
        }

        [HttpGet]
        [Route("GetConfiguration")]
        public IHttpActionResult GetConfiguration()
        {
            try
            {
                var configuration = configurationService.GetConfiguration();
                return Ok(configuration);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }
    }
}
