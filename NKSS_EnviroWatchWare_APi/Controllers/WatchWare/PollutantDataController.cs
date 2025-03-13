using NKSS_EnviroWatchWare_APi.Providers;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [PollutantAuthorize]
    //[Authorize]
    [RoutePrefix("PollutantData")]
    public class PollutantDataController : ApiController
    {
        [HttpGet]
        [Route("Check")]
        public IHttpActionResult Get()
        {
            return Ok();
        }
    }
}
